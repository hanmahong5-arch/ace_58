// NATS slog Handler — 把 slog.Record 异步推到 NATS subject log.<service>。
//
// 为什么要这个？
//
//	AionCore 5 个进程（gateway/world/chat/logd/admin）的运行日志最终
//	要落 ClickHouse 做集中分析。如果每个进程都自己连 ClickHouse，
//	(a) 连接拓扑爆炸 (5 进程 × N 实例)，(b) 热路径上一条 Insert 卡 100ms
//	就拖慢游戏 tick。把日志先扔进 NATS、由独立 logd 批量入库，
//	是 Go 单栈最便宜的解耦——不需要 Vector / OTel collector 这种
//	异构生态适配器。
//
// 关键约束（违反会导致死循环或性能崩塌）：
//
//   - 内部绝对不能调 slog.Default()，不然递归。错误一律 fmt.Fprintln(os.Stderr)。
//   - chan 满时 drop 不阻塞——日志不能因为 NATS 抖动把游戏帧拉爆。
//   - Publisher 是接口，测试用 fake；生产传 *ipc.Client。
package telemetry

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

// Publisher 是 NATSHandler 唯一依赖的发布抽象。
// *ipc.Client 自然满足这个签名（Publish(subject string, v any) error），
// 但接口里改成 []byte 是为了 (a) 测试拿到原始字节方便断言，
// (b) handler 内部已经手工 JSON 序列化，再转 any 多此一举。
type Publisher interface {
	Publish(subject string, data []byte) error
}

// PublisherFunc 让任何 func(string, []byte) error 直接当 Publisher 用，
// 测试里写 mock 不必每次定一个新结构体。
type PublisherFunc func(subject string, data []byte) error

// Publish 实现 Publisher。
func (f PublisherFunc) Publish(subject string, data []byte) error { return f(subject, data) }

// NATSHandlerOptions 控制 NATSHandler 行为。零值即合理默认。
type NATSHandlerOptions struct {
	// Level 控制最低记录级别。零值（LevelInfo）即可。
	Level slog.Level

	// Service 决定 subject 后缀：log.<service>。必填。
	Service string

	// BufferSize 是异步 chan 容量。<=0 取默认 1024。
	BufferSize int

	// Workers 是从 chan 拉数据调 Publisher 的 goroutine 数。<=0 取默认 2。
	Workers int

	// AddSource 为 true 时在每条记录附加 source（file:line）。
	AddSource bool

	// DroppedCounter 在 chan 满 drop 时自增。可绑 prometheus.Counter
	// （它的 Inc() 不带参数，但我们用 *atomic.Int64 兼容更广，prom 那边
	//  用 collectorFunc 把这个数字暴露成 aion_slog_dropped_total）。
	DroppedCounter *atomic.Int64
}

// NATSHandler 实现 slog.Handler，异步把日志记录推 NATS。
//
// 生命周期：
//
//	NewNATSHandler → ... 业务运行 ... → Close(ctx)
//
// Close 会关闭 chan、等所有 worker 把剩余记录发完（或 ctx 超时强退）。
type NATSHandler struct {
	pub       Publisher
	subject   string
	level     slog.Level
	addSource bool
	dropped   *atomic.Int64

	// preformed 记录 WithAttrs 调用时已"绑定"的 attrs，每条带上当时的 group 路径。
	// slog 语义要求 WithAttrs 在"当前 group 上下文"插 attr，后续 WithGroup 改 group
	// 不能改前面那批 attr 的归属——所以必须在 WithAttrs 当下 snapshot groups。
	preformed []preformedAttr

	// groups 是当前激活的 group 路径，仅用于 *Handle* 时给 record-attrs 加前缀。
	groups []string

	// 共享于所有 With* 派生 handler 的内部异步通道与生命周期。
	// 用 *internal 集中管理，避免子 handler 各自 close 把 chan 关多次。
	core *handlerCore
}

// preformedAttr 配 attrs 与它被加入时的 group 路径，避免后来的 WithGroup 改写归属。
type preformedAttr struct {
	groups []string
	attr   slog.Attr
}

type handlerCore struct {
	ch       chan []byte
	wg       sync.WaitGroup
	closeOnce sync.Once
	closed   atomic.Bool
}

// NewNATSHandler 启动 worker goroutine 并返回可立即接 slog.New 的 Handler。
//
// 失败条件：opts.Service 为空。其他字段会做合理 fallback。
func NewNATSHandler(pub Publisher, opts NATSHandlerOptions) (*NATSHandler, error) {
	if pub == nil {
		return nil, fmt.Errorf("telemetry: NATSHandler requires non-nil Publisher")
	}
	if opts.Service == "" {
		return nil, fmt.Errorf("telemetry: NATSHandler requires opts.Service")
	}
	bufSize := opts.BufferSize
	if bufSize <= 0 {
		bufSize = 1024
	}
	workers := opts.Workers
	if workers <= 0 {
		workers = 2
	}
	dropped := opts.DroppedCounter
	if dropped == nil {
		dropped = new(atomic.Int64)
	}

	h := &NATSHandler{
		pub:       pub,
		subject:   "log." + opts.Service,
		level:     opts.Level,
		addSource: opts.AddSource,
		dropped:   dropped,
		core: &handlerCore{
			ch: make(chan []byte, bufSize),
		},
	}

	for i := 0; i < workers; i++ {
		h.core.wg.Add(1)
		go h.runWorker()
	}
	return h, nil
}

// runWorker 拉 chan、调 Publisher。Publisher 错误打到 stderr——
// 不能再走 slog.Default()，会递归。
func (h *NATSHandler) runWorker() {
	defer h.core.wg.Done()
	for data := range h.core.ch {
		if err := h.pub.Publish(h.subject, data); err != nil {
			fmt.Fprintf(os.Stderr, "telemetry: NATSHandler publish %s failed: %v\n", h.subject, err)
		}
	}
}

// Dropped 暴露当前 drop 计数；prom 那边可用 NewCollectorFunc 包装。
func (h *NATSHandler) Dropped() int64 { return h.dropped.Load() }

// Enabled 实现 slog.Handler。
func (h *NATSHandler) Enabled(_ context.Context, level slog.Level) bool {
	return level >= h.level
}

// Handle 序列化 record，丢进 chan。chan 满即 drop——保证调用方零阻塞。
//
// 选择"自己 walk"而非套 slog.NewJSONHandler 是因为：
//
//  1. JSONHandler 写 io.Writer，再用 buffer.Bytes() 取出来要锁，得不偿失；
//  2. 我们的 schema 固定（ts/level/msg/attrs），手写 ~30 行更可控；
//  3. WithGroup 的命名空间嵌套也好直接处理。
func (h *NATSHandler) Handle(_ context.Context, r slog.Record) error {
	if h.core.closed.Load() {
		// 已 Close：drop。slog API 不允许我们返回 "stop calling me"。
		h.dropped.Add(1)
		return nil
	}

	// 1) preformed attrs：每条用它"被加入时"的 group 路径。
	// 2) record 自己的 attrs：用当前激活的 h.groups。
	attrs := make(map[string]any, len(h.preformed)+r.NumAttrs())
	for _, pa := range h.preformed {
		applyAttr(attrs, pa.groups, pa.attr)
	}
	r.Attrs(func(a slog.Attr) bool {
		applyAttr(attrs, h.groups, a)
		return true
	})

	rec := struct {
		TS      string         `json:"ts"`
		Level   string         `json:"level"`
		Msg     string         `json:"msg"`
		Source  string         `json:"source,omitempty"`
		Attrs   map[string]any `json:"attrs,omitempty"`
	}{
		TS:    r.Time.UTC().Format(time.RFC3339Nano),
		Level: r.Level.String(),
		Msg:   r.Message,
		Attrs: attrs,
	}

	if h.addSource && r.PC != 0 {
		fs := runtime.CallersFrames([]uintptr{r.PC})
		if f, _ := fs.Next(); f.File != "" {
			rec.Source = f.File + ":" + strconv.Itoa(f.Line)
		}
	}

	data, err := json.Marshal(rec)
	if err != nil {
		// 编码不该失败，真失败也只能 stderr。
		fmt.Fprintf(os.Stderr, "telemetry: NATSHandler marshal failed: %v\n", err)
		return nil
	}

	// 非阻塞 send：满即 drop。
	select {
	case h.core.ch <- data:
	default:
		h.dropped.Add(1)
	}
	return nil
}

// WithAttrs 实现 slog.Handler。返回新的 handler，共享 core（chan/worker）。
//
// 关键：把每条 attr 与"当前 group 路径"绑死，避免 WithGroup → WithAttrs → WithGroup
// 这种链路把先前 attrs 错误地嵌进新 group。
func (h *NATSHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	if len(attrs) == 0 {
		return h
	}
	cloned := *h
	cloned.preformed = make([]preformedAttr, 0, len(h.preformed)+len(attrs))
	cloned.preformed = append(cloned.preformed, h.preformed...)
	// 共享 h.groups 是只读 slice，安全。
	for _, a := range attrs {
		cloned.preformed = append(cloned.preformed, preformedAttr{groups: h.groups, attr: a})
	}
	return &cloned
}

// WithGroup 实现 slog.Handler。
func (h *NATSHandler) WithGroup(name string) slog.Handler {
	if name == "" {
		return h
	}
	cloned := *h
	cloned.groups = make([]string, 0, len(h.groups)+1)
	cloned.groups = append(cloned.groups, h.groups...)
	cloned.groups = append(cloned.groups, name)
	return &cloned
}

// Close 优雅关闭：拒收新记录、等 worker 把 chan 里剩余 flush 完。
// ctx 超时则强退（剩余 worker 会在它们各自处理完当前消息后退出）。
//
// 多次调用安全。
func (h *NATSHandler) Close(ctx context.Context) error {
	h.core.closeOnce.Do(func() {
		h.core.closed.Store(true)
		close(h.core.ch)
	})
	done := make(chan struct{})
	go func() { h.core.wg.Wait(); close(done) }()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// applyAttr 把单个 slog.Attr 写进 dst map，处理 group 前缀和嵌套 group。
func applyAttr(dst map[string]any, groups []string, a slog.Attr) {
	if a.Equal(slog.Attr{}) {
		return
	}
	v := a.Value.Resolve()

	// Group attr：把 children 当成 sub-map 嵌进去，避免 key collision。
	if v.Kind() == slog.KindGroup {
		sub := make(map[string]any)
		for _, child := range v.Group() {
			applyAttr(sub, nil, child) // group 内部 path 已由 sub map 自身表达
		}
		writeKey(dst, groups, a.Key, sub)
		return
	}
	writeKey(dst, groups, a.Key, slogValueToAny(v))
}

// writeKey 遵循 slog WithGroup 语义：handler-level groups 形成嵌套 map prefix。
func writeKey(dst map[string]any, groups []string, key string, val any) {
	cur := dst
	for _, g := range groups {
		next, ok := cur[g].(map[string]any)
		if !ok {
			next = make(map[string]any)
			cur[g] = next
		}
		cur = next
	}
	cur[key] = val
}

// slogValueToAny 把 slog.Value 转成 JSON 友好的标量/map。
// 时间用 RFC3339Nano；duration 用纳秒数字（标准 slog JSON 默认行为一致）。
func slogValueToAny(v slog.Value) any {
	switch v.Kind() {
	case slog.KindString:
		return v.String()
	case slog.KindBool:
		return v.Bool()
	case slog.KindInt64:
		return v.Int64()
	case slog.KindUint64:
		return v.Uint64()
	case slog.KindFloat64:
		return v.Float64()
	case slog.KindDuration:
		return v.Duration().Nanoseconds()
	case slog.KindTime:
		return v.Time().UTC().Format(time.RFC3339Nano)
	case slog.KindAny:
		return v.Any()
	default:
		return v.String()
	}
}
