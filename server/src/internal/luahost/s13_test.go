// Package luahost — Phase S-13 regression tests.
//
// Covers the jobq Lua binding:
//   - jobq global is a table exposing enqueue
//   - jobq.enqueue on a Bridge with nil Jobs returns (false, "disabled")
//   - jobq.enqueue with a wired mock JobQueue records kind + JSON payload
//   - nested Lua tables are serialised into JSON objects / arrays
//   - enqueue error path (mock returning err) surfaces the message to Lua
package luahost

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

var s13ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// --- Mock JobQueue -------------------------------------------------------

type enqueuedJob struct {
	kind    string
	payload []byte
	delay   time.Duration // zero for EnqueueKind, >0 for EnqueueKindIn
}

type mockJobQueue struct {
	mu   sync.Mutex
	jobs []enqueuedJob
	// err, when non-nil, is returned by every Enqueue* call.
	err error
}

func (m *mockJobQueue) EnqueueKind(ctx context.Context, kind string, payload []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.jobs = append(m.jobs, enqueuedJob{
		kind:    kind,
		payload: append([]byte(nil), payload...),
	})
	return m.err
}

func (m *mockJobQueue) EnqueueKindIn(ctx context.Context, kind string, payload []byte, delay time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.jobs = append(m.jobs, enqueuedJob{
		kind:    kind,
		payload: append([]byte(nil), payload...),
		delay:   delay,
	})
	return m.err
}

func (m *mockJobQueue) last() (enqueuedJob, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if len(m.jobs) == 0 {
		return enqueuedJob{}, false
	}
	return m.jobs[len(m.jobs)-1], true
}

// --- Harness -------------------------------------------------------------

func newS13Bridge(t *testing.T, jobs JobQueue) (*Bridge, *lua.LState) {
	t.Helper()
	world := ecs.NewWorld()
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: &mockCaptureSender{}, Jobs: jobs}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s13ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s13 loadScripts: %v", err)
	}
	return b, L
}

// execLua runs a Lua snippet that is expected to return one or two values.
// Returns the stack contents as LValues so tests can inspect multi-return.
func execLua(t *testing.T, L *lua.LState, snippet string) []lua.LValue {
	t.Helper()
	base := L.GetTop()
	if err := L.DoString(snippet); err != nil {
		t.Fatalf("DoString(%q): %v", snippet, err)
	}
	top := L.GetTop()
	out := make([]lua.LValue, 0, top-base)
	for i := base + 1; i <= top; i++ {
		out = append(out, L.Get(i))
	}
	L.SetTop(base)
	return out
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqLibLoaded — jobq global table with an enqueue function exists.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqLibLoaded(t *testing.T) {
	_, L := newS13Bridge(t, nil)
	defer L.Close()

	tbl, ok := L.GetGlobal("jobq").(*lua.LTable)
	if !ok {
		t.Fatalf("expected jobq to be a table, got %T", L.GetGlobal("jobq"))
	}
	if _, ok := L.GetField(tbl, "enqueue").(*lua.LFunction); !ok {
		t.Fatalf("expected jobq.enqueue function, got %T", L.GetField(tbl, "enqueue"))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueDisabled — nil Jobs returns (false, "disabled").
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueDisabled(t *testing.T) {
	_, L := newS13Bridge(t, nil)
	defer L.Close()

	ret := execLua(t, L, `return jobq.enqueue("test.kind", { foo = 1 })`)
	if len(ret) != 2 {
		t.Fatalf("expected 2 return values, got %d", len(ret))
	}
	if ret[0] != lua.LFalse {
		t.Errorf("expected false on disabled, got %v", ret[0])
	}
	if ret[1].String() != "disabled" {
		t.Errorf("expected reason \"disabled\", got %q", ret[1].String())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueRoutesToMock — wired Jobs receives the kind + payload.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueRoutesToMock(t *testing.T) {
	jq := &mockJobQueue{}
	_, L := newS13Bridge(t, jq)
	defer L.Close()

	ret := execLua(t, L, `return jobq.enqueue("aion58.cron.daily_reset", { when = "tomorrow" })`)
	if len(ret) != 1 || ret[0] != lua.LTrue {
		t.Fatalf("expected single true return, got %v", ret)
	}

	last, ok := jq.last()
	if !ok {
		t.Fatal("mockJobQueue received no jobs")
	}
	if last.kind != "aion58.cron.daily_reset" {
		t.Errorf("expected kind 'aion58.cron.daily_reset', got %q", last.kind)
	}

	// Payload must be valid JSON and contain the expected field.
	var decoded map[string]any
	if err := json.Unmarshal(last.payload, &decoded); err != nil {
		t.Fatalf("payload is not valid JSON: %v (raw=%s)", err, last.payload)
	}
	if decoded["when"] != "tomorrow" {
		t.Errorf("expected decoded.when == 'tomorrow', got %v", decoded["when"])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueEmptyArgs — nil args_table serialises as empty object.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueEmptyArgs(t *testing.T) {
	jq := &mockJobQueue{}
	_, L := newS13Bridge(t, jq)
	defer L.Close()

	ret := execLua(t, L, `return jobq.enqueue("test.empty")`)
	if len(ret) != 1 || ret[0] != lua.LTrue {
		t.Fatalf("expected true return, got %v", ret)
	}
	last, _ := jq.last()
	if string(last.payload) != "{}" {
		t.Errorf("expected empty object payload, got %q", last.payload)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueNestedTable — nested tables serialised as JSON objects.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueNestedTable(t *testing.T) {
	jq := &mockJobQueue{}
	_, L := newS13Bridge(t, jq)
	defer L.Close()

	snippet := `return jobq.enqueue("test.nested", {
		sender = 101,
		recipient = 202,
		mail = { subject = "hi", body = "there" }
	})`
	ret := execLua(t, L, snippet)
	if len(ret) != 1 || ret[0] != lua.LTrue {
		t.Fatalf("expected true return, got %v", ret)
	}
	last, _ := jq.last()

	var decoded map[string]any
	if err := json.Unmarshal(last.payload, &decoded); err != nil {
		t.Fatalf("payload JSON parse: %v (raw=%s)", err, last.payload)
	}
	if decoded["sender"] != float64(101) {
		t.Errorf("sender mismatch: %v", decoded["sender"])
	}
	mail, ok := decoded["mail"].(map[string]any)
	if !ok {
		t.Fatalf("expected mail nested object, got %T", decoded["mail"])
	}
	if mail["subject"] != "hi" {
		t.Errorf("mail.subject mismatch: %v", mail["subject"])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueArrayTable — sequential integer-keyed table → JSON array.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueArrayTable(t *testing.T) {
	jq := &mockJobQueue{}
	_, L := newS13Bridge(t, jq)
	defer L.Close()

	snippet := `return jobq.enqueue("test.array", { ids = {10, 20, 30} })`
	ret := execLua(t, L, snippet)
	if len(ret) != 1 || ret[0] != lua.LTrue {
		t.Fatalf("expected true, got %v", ret)
	}
	last, _ := jq.last()

	var decoded map[string]any
	if err := json.Unmarshal(last.payload, &decoded); err != nil {
		t.Fatalf("JSON parse: %v", err)
	}
	arr, ok := decoded["ids"].([]any)
	if !ok {
		t.Fatalf("expected ids array, got %T", decoded["ids"])
	}
	if len(arr) != 3 || arr[0] != float64(10) || arr[2] != float64(30) {
		t.Errorf("array contents wrong: %v", arr)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestJobqEnqueueReportsError — EnqueueKind error surfaces to Lua.
// ─────────────────────────────────────────────────────────────────────────
func TestJobqEnqueueReportsError(t *testing.T) {
	jq := &mockJobQueue{err: errors.New("boom")}
	_, L := newS13Bridge(t, jq)
	defer L.Close()

	ret := execLua(t, L, `return jobq.enqueue("test.err", { x = 1 })`)
	if len(ret) != 2 {
		t.Fatalf("expected 2 returns on error, got %d", len(ret))
	}
	if ret[0] != lua.LFalse {
		t.Errorf("expected false on error, got %v", ret[0])
	}
	if ret[1].String() != "boom" {
		t.Errorf("expected error message 'boom', got %q", ret[1].String())
	}
}
