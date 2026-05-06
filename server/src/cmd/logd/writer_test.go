package main

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

// fakeWriter 是 batchWriter 的 in-memory 实现：
// 记录每次 Append 的 record、每次 Flush 的"截止行数"，让测试断言 flush 触发点。
type fakeWriter struct {
	mu sync.Mutex

	appends   []logRecord
	services  []string
	flushes   []int   // 每次 Flush 时已经累积的 records 数；len(flushes)=flush 次数
	closed    bool
	failNext  error
}

func (f *fakeWriter) Append(rec logRecord, service string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.failNext != nil {
		err := f.failNext
		f.failNext = nil
		return err
	}
	f.appends = append(f.appends, rec)
	f.services = append(f.services, service)
	return nil
}

func (f *fakeWriter) Flush(_ context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.flushes = append(f.flushes, len(f.appends))
	return nil
}

func (f *fakeWriter) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closed = true
	return nil
}

func (f *fakeWriter) snapshotFlushes() []int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]int(nil), f.flushes...)
}

func (f *fakeWriter) appendCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.appends)
}

// TestBatcher_FlushOnRowLimit 验证攒满 maxRows 立即 flush。
func TestBatcher_FlushOnRowLimit(t *testing.T) {
	w := &fakeWriter{}
	b := newBatcher(w, 3, time.Hour) // maxAge 设极长，确保只有 row limit 触发

	ctx := context.Background()
	for i := 0; i < 7; i++ {
		if err := b.add(ctx, logRecord{Msg: "x"}, "gateway"); err != nil {
			t.Fatalf("add: %v", err)
		}
	}
	flushes := w.snapshotFlushes()
	// 期望：第 3 条 add 后 flush 一次（累计 3）；第 6 条后 flush 一次（累计 6）。
	if len(flushes) != 2 {
		t.Fatalf("flushes = %v, want 2 flushes for 7 rows with limit 3", flushes)
	}
	if flushes[0] != 3 || flushes[1] != 6 {
		t.Errorf("flush points = %v, want [3 6]", flushes)
	}
	// 还剩 1 条 buffered（第 7 条）
	if got := b.pendingCount(); got != 1 {
		t.Errorf("pending after flushes = %d, want 1", got)
	}
}

// TestBatcher_FlushOnAgeViaTick 验证超过 maxAge 的 tick 触发 flush。
func TestBatcher_FlushOnAgeViaTick(t *testing.T) {
	w := &fakeWriter{}
	b := newBatcher(w, 1000, 20*time.Millisecond)

	ctx := context.Background()
	if err := b.add(ctx, logRecord{Msg: "first"}, "world"); err != nil {
		t.Fatalf("add: %v", err)
	}
	// tick 太早：不该 flush。
	if err := b.tick(ctx); err != nil {
		t.Fatalf("tick early: %v", err)
	}
	if got := len(w.snapshotFlushes()); got != 0 {
		t.Errorf("early tick flushed %d times, want 0", got)
	}

	time.Sleep(40 * time.Millisecond)
	if err := b.tick(ctx); err != nil {
		t.Fatalf("tick after age: %v", err)
	}
	flushes := w.snapshotFlushes()
	if len(flushes) != 1 || flushes[0] != 1 {
		t.Errorf("age tick flushes = %v, want [1]", flushes)
	}
	if b.pendingCount() != 0 {
		t.Errorf("pending after age flush = %d, want 0", b.pendingCount())
	}
}

// TestBatcher_TickEmptyNoOp 验证空 batch 的 tick 不调 Flush。
func TestBatcher_TickEmptyNoOp(t *testing.T) {
	w := &fakeWriter{}
	b := newBatcher(w, 100, time.Millisecond)
	time.Sleep(5 * time.Millisecond)
	if err := b.tick(context.Background()); err != nil {
		t.Fatalf("tick: %v", err)
	}
	if got := len(w.snapshotFlushes()); got != 0 {
		t.Errorf("empty tick flushed %d times, want 0", got)
	}
}

// TestBatcher_CloseFlushesPending 验证 close 把残留 batch 写出去并关 writer。
func TestBatcher_CloseFlushesPending(t *testing.T) {
	w := &fakeWriter{}
	b := newBatcher(w, 1000, time.Hour)
	ctx := context.Background()

	for i := 0; i < 5; i++ {
		_ = b.add(ctx, logRecord{Msg: "x"}, "chat")
	}
	if err := b.close(ctx); err != nil {
		t.Fatalf("close: %v", err)
	}
	flushes := w.snapshotFlushes()
	if len(flushes) != 1 || flushes[0] != 5 {
		t.Errorf("close flushes = %v, want [5]", flushes)
	}
	if !w.closed {
		t.Errorf("writer not closed")
	}
}

// TestBatcher_AppendErrorPropagates 验证 writer.Append 失败把错误抛回调用方。
func TestBatcher_AppendErrorPropagates(t *testing.T) {
	w := &fakeWriter{failNext: errors.New("boom")}
	b := newBatcher(w, 100, time.Hour)
	err := b.add(context.Background(), logRecord{Msg: "x"}, "admin")
	if err == nil {
		t.Fatal("expected error from append")
	}
	if w.appendCount() != 0 {
		t.Errorf("failed append still recorded: %d", w.appendCount())
	}
}

// TestServiceFromSubject 验证 subject → service 解析。
func TestServiceFromSubject(t *testing.T) {
	cases := map[string]string{
		"log.gateway":         "gateway",
		"log.world.session":   "world.session", // 多级 subject 整体当作 service id
		"log.":                "",
		"unrelated.gateway":   "unrelated.gateway", // 非 log.* 原样返回
	}
	for in, want := range cases {
		if got := serviceFromSubject(in); got != want {
			t.Errorf("serviceFromSubject(%q) = %q, want %q", in, got, want)
		}
	}
}

// TestRedactDSN 验证敏感字段不进日志。
func TestRedactDSN(t *testing.T) {
	cases := map[string]string{
		"clickhouse://user:secret@host:9000/db": "clickhouse://***@host:9000/db",
		"tcp://127.0.0.1:9000?database=aion":    "tcp://127.0.0.1:9000?database=aion", // 无 @ 不动
	}
	for in, want := range cases {
		if got := redactDSN(in); got != want {
			t.Errorf("redactDSN(%q) = %q, want %q", in, got, want)
		}
	}
}
