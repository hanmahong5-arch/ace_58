package telemetry

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// recordingPub 是一个线程安全的 in-memory Publisher，记录所有 Publish 调用。
type recordingPub struct {
	mu      sync.Mutex
	records [][]byte
	subjects []string

	// blockUntil 不为 nil 时，每次 Publish 会阻塞到 channel 关闭，
	// 用来制造"worker 卡住、chan 灌满"的 drop 场景。
	blockUntil chan struct{}

	// failOnce 为 true 时第一次返回 error，再调正常。验证错误打 stderr 不崩。
	failOnce atomic.Bool
}

func (p *recordingPub) Publish(subject string, data []byte) error {
	if p.blockUntil != nil {
		<-p.blockUntil
	}
	if p.failOnce.CompareAndSwap(true, false) {
		return errors.New("simulated publish failure")
	}
	// data 是 worker goroutine 借用的 slice，必须 copy 后存。
	cp := make([]byte, len(data))
	copy(cp, data)
	p.mu.Lock()
	p.records = append(p.records, cp)
	p.subjects = append(p.subjects, subject)
	p.mu.Unlock()
	return nil
}

func (p *recordingPub) snapshot() ([]string, [][]byte) {
	p.mu.Lock()
	defer p.mu.Unlock()
	s := append([]string(nil), p.subjects...)
	r := append([][]byte(nil), p.records...)
	return s, r
}

func newTestHandler(t *testing.T, pub Publisher, opts NATSHandlerOptions) *NATSHandler {
	t.Helper()
	if opts.Service == "" {
		opts.Service = "testsvc"
	}
	h, err := NewNATSHandler(pub, opts)
	if err != nil {
		t.Fatalf("NewNATSHandler: %v", err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = h.Close(ctx)
	})
	return h
}

// 等 publisher 收到至少 n 条记录或超时。比 sleep 鲁棒。
func waitForRecords(t *testing.T, pub *recordingPub, n int, deadline time.Duration) {
	t.Helper()
	stop := time.Now().Add(deadline)
	for time.Now().Before(stop) {
		_, recs := pub.snapshot()
		if len(recs) >= n {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	subs, recs := pub.snapshot()
	t.Fatalf("waitForRecords: expected >=%d records, got %d (subjects=%v)", n, len(recs), subs)
}

// TestNATSHandler_BasicInfoFlow 验证最基础链路：log.Info → publisher 收到。
func TestNATSHandler_BasicInfoFlow(t *testing.T) {
	pub := &recordingPub{}
	h := newTestHandler(t, pub, NATSHandlerOptions{Service: "gateway"})
	logger := slog.New(h)

	logger.Info("hello", "char_id", 42, "zone", "elysea")
	waitForRecords(t, pub, 1, time.Second)

	subjects, recs := pub.snapshot()
	if subjects[0] != "log.gateway" {
		t.Fatalf("subject = %q, want log.gateway", subjects[0])
	}

	var got map[string]any
	if err := json.Unmarshal(recs[0], &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got["msg"] != "hello" {
		t.Errorf("msg = %v, want hello", got["msg"])
	}
	if got["level"] != "INFO" {
		t.Errorf("level = %v, want INFO", got["level"])
	}
	attrs, _ := got["attrs"].(map[string]any)
	if attrs["char_id"].(float64) != 42 {
		t.Errorf("attrs.char_id = %v, want 42", attrs["char_id"])
	}
	if attrs["zone"] != "elysea" {
		t.Errorf("attrs.zone = %v, want elysea", attrs["zone"])
	}
}

// TestNATSHandler_LevelFilter 验证 Enabled 过滤低于阈值的 record。
func TestNATSHandler_LevelFilter(t *testing.T) {
	pub := &recordingPub{}
	h := newTestHandler(t, pub, NATSHandlerOptions{
		Service: "world",
		Level:   slog.LevelWarn,
	})
	logger := slog.New(h)

	logger.Info("ignored")
	logger.Debug("ignored2")
	logger.Warn("kept", "k", 1)
	logger.Error("kept-too")
	waitForRecords(t, pub, 2, time.Second)

	_, recs := pub.snapshot()
	if len(recs) != 2 {
		t.Fatalf("got %d records, want 2", len(recs))
	}
}

// TestNATSHandler_DropOnFullBuffer 验证 chan 满后 drop 不阻塞调用方，
// 并把 dropped 计数加上去。
func TestNATSHandler_DropOnFullBuffer(t *testing.T) {
	block := make(chan struct{})
	pub := &recordingPub{blockUntil: block}
	dropped := new(atomic.Int64)

	h := newTestHandler(t, pub, NATSHandlerOptions{
		Service:        "chat",
		BufferSize:     2,
		Workers:        1,
		DroppedCounter: dropped,
	})
	logger := slog.New(h)

	// 灌 50 条；worker 卡在 blockUntil，chan 容量 2 + worker 持有 1 条 ≈ 3 条不丢。
	// 余下 ≥47 条必 drop。
	for i := 0; i < 50; i++ {
		logger.Info("flood", "i", i)
	}
	close(block) // 解锁 worker，让队列里的 ≤3 条流走

	// 等 dropped 计数稳定（worker drain 后不再变）
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if dropped.Load() > 40 {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if dropped.Load() < 40 {
		t.Fatalf("dropped = %d, want >=40 (chan cap 2 + worker drain)", dropped.Load())
	}
	if h.Dropped() != dropped.Load() {
		t.Errorf("Dropped() = %d, dropped.Load() = %d, must agree", h.Dropped(), dropped.Load())
	}
}

// TestNATSHandler_WithAttrsAndWithGroup 验证派生 handler 不丢字段、group 嵌套正确。
func TestNATSHandler_WithAttrsAndWithGroup(t *testing.T) {
	pub := &recordingPub{}
	h := newTestHandler(t, pub, NATSHandlerOptions{Service: "world"})

	// .With 累积 attrs；.WithGroup 给后续 attrs 嵌套命名空间。
	logger := slog.New(h).With("base", "v0").WithGroup("scope").With("inner", 7)
	logger.Info("event", "extra", "x")
	waitForRecords(t, pub, 1, time.Second)

	_, recs := pub.snapshot()
	var got struct {
		Attrs map[string]any `json:"attrs"`
	}
	if err := json.Unmarshal(recs[0], &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Attrs["base"] != "v0" {
		t.Errorf("base attr lost: %v", got.Attrs)
	}
	scope, ok := got.Attrs["scope"].(map[string]any)
	if !ok {
		t.Fatalf("scope group missing or wrong type: %v", got.Attrs)
	}
	if scope["inner"].(float64) != 7 {
		t.Errorf("scope.inner = %v, want 7", scope["inner"])
	}
	if scope["extra"] != "x" {
		t.Errorf("scope.extra = %v, want x", scope["extra"])
	}
}

// TestNATSHandler_CloseFlushesPending 验证 Close 等 worker 把 chan 里剩余 flush 完。
func TestNATSHandler_CloseFlushesPending(t *testing.T) {
	pub := &recordingPub{}
	h, err := NewNATSHandler(pub, NATSHandlerOptions{Service: "logd", BufferSize: 64, Workers: 1})
	if err != nil {
		t.Fatalf("new: %v", err)
	}
	logger := slog.New(h)
	for i := 0; i < 10; i++ {
		logger.Info("msg", "i", i)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := h.Close(ctx); err != nil {
		t.Fatalf("Close: %v", err)
	}
	_, recs := pub.snapshot()
	if len(recs) != 10 {
		t.Fatalf("got %d records, want 10 (Close must flush)", len(recs))
	}

	// 多次 Close 安全。
	if err := h.Close(ctx); err != nil {
		t.Errorf("second Close: %v", err)
	}

	// Close 后再 log，丢弃且 dropped++，绝不 panic。
	before := h.Dropped()
	logger.Info("post-close")
	if h.Dropped() <= before {
		t.Errorf("dropped not incremented after Close")
	}
}

// TestNATSHandler_PublishErrorIsSwallowed 验证 publisher 失败不影响后续记录。
func TestNATSHandler_PublishErrorIsSwallowed(t *testing.T) {
	pub := &recordingPub{}
	pub.failOnce.Store(true)

	h := newTestHandler(t, pub, NATSHandlerOptions{Service: "admin", Workers: 1})
	logger := slog.New(h)

	logger.Info("first-will-fail-publish")
	logger.Info("second-must-succeed")
	waitForRecords(t, pub, 1, time.Second)

	_, recs := pub.snapshot()
	if len(recs) < 1 {
		t.Fatalf("expected at least the second record to land, got %d", len(recs))
	}
}

// TestNATSHandler_RejectsBadOptions 验证 NewNATSHandler 在缺必填项时拒绝。
func TestNATSHandler_RejectsBadOptions(t *testing.T) {
	if _, err := NewNATSHandler(nil, NATSHandlerOptions{Service: "x"}); err == nil {
		t.Error("nil publisher should fail")
	}
	pub := PublisherFunc(func(string, []byte) error { return nil })
	if _, err := NewNATSHandler(pub, NATSHandlerOptions{}); err == nil {
		t.Error("empty Service should fail")
	}
}

// TestNATSHandler_AddSourceAttachesFileLine 验证 AddSource 选项填 source。
func TestNATSHandler_AddSourceAttachesFileLine(t *testing.T) {
	pub := &recordingPub{}
	h := newTestHandler(t, pub, NATSHandlerOptions{Service: "gateway", AddSource: true})
	logger := slog.New(h)

	// 让 slog 抓到 PC——只要从 logger 调一次就行。
	logger.Info("with-source")
	waitForRecords(t, pub, 1, time.Second)

	_, recs := pub.snapshot()
	var got map[string]any
	_ = json.Unmarshal(recs[0], &got)
	src, _ := got["source"].(string)
	if src == "" {
		t.Errorf("source missing when AddSource=true")
	}
}
