package jobq

import (
	"context"
	"testing"

	"github.com/hibiken/asynq"
)

// TestNewWithNoBackends verifies the facade constructs cleanly when both
// river and asynq are disabled. Callers should still receive a non-nil
// Bundle whose Enqueue* methods are no-ops.
func TestNewWithNoBackends(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if b == nil {
		t.Fatal("Bundle should be non-nil even when all backends are disabled")
	}
	if b.RiverClient() != nil {
		t.Error("RiverClient should be nil without a PG pool")
	}
	if b.AsynqClient() != nil {
		t.Error("AsynqClient should be nil without Redis opt")
	}
	if b.AsynqScheduler() != nil {
		t.Error("AsynqScheduler should be nil without Redis opt")
	}
}

// TestEnqueueKindNilSafe verifies EnqueueKind returns nil when asynq is
// disabled, so Lua scripts can call jobq.enqueue without branching on
// environment availability.
func TestEnqueueKindNilSafe(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := b.EnqueueKind(context.Background(), "test.kind", []byte(`{}`)); err != nil {
		t.Errorf("EnqueueKind on disabled bundle should return nil, got %v", err)
	}
}

// TestEnqueueAsynqNilSafe mirrors EnqueueKind for the pre-built-task path.
func TestEnqueueAsynqNilSafe(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	task := asynq.NewTask("test.kind", []byte(`{}`))
	info, err := b.EnqueueAsynq(context.Background(), task)
	if err != nil {
		t.Errorf("EnqueueAsynq on disabled bundle should return nil err, got %v", err)
	}
	if info != nil {
		t.Error("Expected nil TaskInfo when asynq is disabled")
	}
}

// TestRegisterCronNilSafe ensures cron registration is a no-op when asynq
// scheduler is unavailable, returning an empty entry ID without error.
func TestRegisterCronNilSafe(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	task := asynq.NewTask("test.kind", nil)
	id, err := b.RegisterCron("@every 1m", task)
	if err != nil {
		t.Errorf("RegisterCron on disabled bundle should return nil err, got %v", err)
	}
	if id != "" {
		t.Errorf("Expected empty entry ID, got %q", id)
	}
}

// TestCloseNilSafe verifies Close handles a fully disabled bundle without
// panicking. Important because Close is always called via defer in main.go.
func TestCloseNilSafe(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// Should not panic, should not block.
	b.Close(context.Background())
}

// TestCloseNilBundle verifies Close handles a literal nil receiver, so
// deferred cleanup in main.go cannot panic on an init error path.
func TestCloseNilBundle(t *testing.T) {
	var b *Bundle
	b.Close(context.Background()) // must not panic
}

// TestJobArgsKinds pins the kind strings to their wire-stable values.
// Renaming these would orphan river jobs already persisted in PG.
func TestJobArgsKinds(t *testing.T) {
	tests := []struct {
		name     string
		got      string
		expected string
	}{
		{"MailDeliverArgs", MailDeliverArgs{}.Kind(), "aion58.mail.deliver"},
		{"LegionInviteExpireArgs", LegionInviteExpireArgs{}.Kind(), "aion58.legion.invite_expire"},
	}
	for _, tc := range tests {
		if tc.got != tc.expected {
			t.Errorf("%s.Kind() = %q, want %q", tc.name, tc.got, tc.expected)
		}
	}
}

// TestAsynqKindConstants pins the cron kind constants.
func TestAsynqKindConstants(t *testing.T) {
	cases := map[string]string{
		"KindDailyReset":     KindDailyReset,
		"KindPvpAPBatch":     KindPvpAPBatch,
		"KindWorldBossSpawn": KindWorldBossSpawn,
	}
	expected := map[string]string{
		"KindDailyReset":     "aion58.cron.daily_reset",
		"KindPvpAPBatch":     "aion58.cron.pvp_ap_batch",
		"KindWorldBossSpawn": "aion58.cron.world_boss_spawn",
	}
	for name, got := range cases {
		if got != expected[name] {
			t.Errorf("%s = %q, want %q", name, got, expected[name])
		}
	}
}

// TestDefaultRiverWorkers verifies the default worker bundle assembles
// without panic (the exercise is that AddWorker does not conflict on types).
func TestDefaultRiverWorkers(t *testing.T) {
	ws := DefaultRiverWorkers(nil, nil)
	if ws == nil {
		t.Fatal("DefaultRiverWorkers returned nil")
	}
}

// TestDefaultAsynqMux verifies the default mux can be constructed and has
// all expected kind handlers registered.
func TestDefaultAsynqMux(t *testing.T) {
	mux := DefaultAsynqMux(nil, nil)
	if mux == nil {
		t.Fatal("DefaultAsynqMux returned nil")
	}
	// asynq.ServeMux does not expose a direct "has handler" check, but we
	// can dispatch a task and rely on the handler not erroring for the
	// registered kinds. Dispatching is synchronous.
	tests := []string{KindDailyReset, KindPvpAPBatch, KindWorldBossSpawn}
	for _, kind := range tests {
		task := asynq.NewTask(kind, []byte(`{}`))
		if err := mux.ProcessTask(context.Background(), task); err != nil {
			t.Errorf("ProcessTask(%s): %v", kind, err)
		}
	}
}
