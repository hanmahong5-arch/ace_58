// logd batch accumulator + writer abstraction.
//
// 为什么把 writer 抽成接口？
//
//	ClickHouse 不好 mock（要起容器）。把"接收一批 log record，落盘"
//	抽成 batchWriter 接口后：
//	  - main.go 里的 batcher 只关心 "5s 或 1000 条 flush 一次" 这件事；
//	  - 测试用 fakeWriter 直接断言 batch 触发逻辑；
//	  - 真 ClickHouse writer 是另一个实现，独立单元测试可选。
//
//	这是 boring Go——别再加抽象层（Sink/Pipeline/Stage 通通不要）。
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

// logRecord 是 NATS 上传过来的一条 slog 记录。字段对应 sloghandler.go 的输出 schema。
type logRecord struct {
	TS     string          `json:"ts"`
	Level  string          `json:"level"`
	Msg    string          `json:"msg"`
	Source string          `json:"source,omitempty"`
	Attrs  json.RawMessage `json:"attrs,omitempty"`
}

// batchWriter 是落盘抽象。生产实现走 ClickHouse；测试用 fake。
//
// Append 不必并发安全——batcher 串行调；Flush 同理。
type batchWriter interface {
	Append(rec logRecord, service string) error
	Flush(ctx context.Context) error
	Close() error
}

// batcher 累积 record、按"5s 或 N 条"二者先到 flush。
//
// 使用模式：
//
//	b := newBatcher(writer, 1000, 5*time.Second)
//	for msg := range subCh { b.add(...) }
//	b.close(ctx)
type batcher struct {
	w        batchWriter
	maxRows  int
	maxAge   time.Duration

	mu       sync.Mutex
	buffered int
	oldest   time.Time
}

func newBatcher(w batchWriter, maxRows int, maxAge time.Duration) *batcher {
	return &batcher{w: w, maxRows: maxRows, maxAge: maxAge}
}

// add 把一条记录加入 batch；若加完后达到 maxRows，立即 flush。
// 调用方需周期性调 tick(ctx)（见 main.go 的 ticker）来覆盖 maxAge 触发。
func (b *batcher) add(ctx context.Context, rec logRecord, service string) error {
	b.mu.Lock()
	if b.buffered == 0 {
		b.oldest = time.Now()
	}
	if err := b.w.Append(rec, service); err != nil {
		b.mu.Unlock()
		return err
	}
	b.buffered++
	shouldFlush := b.buffered >= b.maxRows
	b.mu.Unlock()
	if shouldFlush {
		return b.flushLocked(ctx)
	}
	return nil
}

// tick 是 ticker goroutine 调的——若 batch 老到超过 maxAge 就 flush。
func (b *batcher) tick(ctx context.Context) error {
	b.mu.Lock()
	if b.buffered == 0 || time.Since(b.oldest) < b.maxAge {
		b.mu.Unlock()
		return nil
	}
	b.mu.Unlock()
	return b.flushLocked(ctx)
}

// flushLocked 调 writer.Flush 并重置计数。注意名字带 Locked 但其实是
// "外部已释放锁、内部需要短期再持锁重置状态"——避免 Flush 时长持锁。
func (b *batcher) flushLocked(ctx context.Context) error {
	if err := b.w.Flush(ctx); err != nil {
		return err
	}
	b.mu.Lock()
	b.buffered = 0
	b.mu.Unlock()
	return nil
}

// close flush 剩余数据并关 writer。
func (b *batcher) close(ctx context.Context) error {
	b.mu.Lock()
	pending := b.buffered
	b.mu.Unlock()
	if pending > 0 {
		if err := b.flushLocked(ctx); err != nil {
			return err
		}
	}
	return b.w.Close()
}

// pendingCount 暴露当前未 flush 行数，给测试断言。
func (b *batcher) pendingCount() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buffered
}

// ---------- ClickHouse 实现 ----------

// chWriter 是生产 writer：每个 Append 把行加进当前 prepared batch；
// Flush 调 batch.Send() 并起一个新 batch。
type chWriter struct {
	conn  driver.Conn
	mu    sync.Mutex
	batch driver.Batch // 懒初始化；Send 后置 nil，下次 Append 重建
}

func newCHWriter(ctx context.Context, dsn string) (*chWriter, error) {
	opts, err := clickhouse.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse clickhouse dsn: %w", err)
	}
	conn, err := clickhouse.Open(opts)
	if err != nil {
		return nil, fmt.Errorf("open clickhouse: %w", err)
	}
	if err := conn.Ping(ctx); err != nil {
		_ = conn.Close()
		return nil, fmt.Errorf("ping clickhouse: %w", err)
	}
	return &chWriter{conn: conn}, nil
}

// ensureBatch 懒初始化 prepared batch。clickhouse-go v2 的 batch
// 在 Send 后即关闭，下条 Append 必须新建。
func (w *chWriter) ensureBatch(ctx context.Context) error {
	if w.batch != nil {
		return nil
	}
	b, err := w.conn.PrepareBatch(ctx, "INSERT INTO log_events (ts, service, level, msg, attrs)")
	if err != nil {
		return fmt.Errorf("prepare batch: %w", err)
	}
	w.batch = b
	return nil
}

func (w *chWriter) Append(rec logRecord, service string) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	// Append 复用上一个 batch；如果上次 Flush 后还没新 batch，先建。
	if err := w.ensureBatch(context.Background()); err != nil {
		return err
	}
	ts, err := time.Parse(time.RFC3339Nano, rec.TS)
	if err != nil {
		// ts 解不出来用 now，避免一条坏记录卡住整个 batch。
		ts = time.Now().UTC()
	}
	attrs := string(rec.Attrs)
	if attrs == "" {
		attrs = "{}"
	}
	return w.batch.Append(ts, service, rec.Level, rec.Msg, attrs)
}

func (w *chWriter) Flush(_ context.Context) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.batch == nil {
		return nil
	}
	if err := w.batch.Send(); err != nil {
		return fmt.Errorf("send batch: %w", err)
	}
	w.batch = nil
	return nil
}

func (w *chWriter) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.batch != nil {
		_ = w.batch.Send()
		w.batch = nil
	}
	if w.conn != nil {
		return w.conn.Close()
	}
	return nil
}
