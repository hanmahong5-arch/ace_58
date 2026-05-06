package jobq

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/hibiken/asynq"
	"github.com/riverqueue/river"
)

// recordingInvoker captures CallGlobal invocations for assertion.
// Goroutine-safe because jobq workers may be invoked from multiple river /
// asynq goroutines concurrently.
type recordingInvoker struct {
	mu    sync.Mutex
	calls []call
	err   error
}

type call struct {
	fn   string
	args []any
}

func (r *recordingInvoker) CallGlobal(fn string, args ...any) error {
	r.mu.Lock()
	r.calls = append(r.calls, call{fn: fn, args: append([]any(nil), args...)})
	r.mu.Unlock()
	return r.err
}

func (r *recordingInvoker) lastFn() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	if len(r.calls) == 0 {
		return ""
	}
	return r.calls[len(r.calls)-1].fn
}

// TestMailDeliverWorkerDelegates covers the non-nil-invoker path of
// MailDeliverWorker.Work including the argument ordering contract.
func TestMailDeliverWorkerDelegates(t *testing.T) {
	inv := &recordingInvoker{}
	w := &MailDeliverWorker{Invoker: inv}
	job := &river.Job[MailDeliverArgs]{Args: MailDeliverArgs{
		SenderCharID:      10,
		RecipientCharID:   20,
		Subject:           "S",
		Body:              "B",
		AttachedItemID:    5,
		AttachedItemCount: 2,
		AttachedKinah:     100,
	}}
	if err := w.Work(context.Background(), job); err != nil {
		t.Fatalf("Work err: %v", err)
	}
	if inv.lastFn() != LuaFnMailDeliver {
		t.Errorf("expected CallGlobal(%s), got %s", LuaFnMailDeliver, inv.lastFn())
	}
	if len(inv.calls[0].args) != 7 {
		t.Errorf("expected 7 args, got %d", len(inv.calls[0].args))
	}
}

// TestMailDeliverWorkerNilInvoker covers the dev-environment no-op branch.
func TestMailDeliverWorkerNilInvoker(t *testing.T) {
	w := &MailDeliverWorker{} // Invoker nil
	if err := w.Work(context.Background(), &river.Job[MailDeliverArgs]{}); err != nil {
		t.Errorf("nil-invoker Work should return nil, got %v", err)
	}
}

// TestLegionInviteExpireWorker mirrors the mail worker contract.
func TestLegionInviteExpireWorker(t *testing.T) {
	inv := &recordingInvoker{err: errors.New("boom")}
	w := &LegionInviteExpireWorker{Invoker: inv}
	err := w.Work(context.Background(), &river.Job[LegionInviteExpireArgs]{
		Args: LegionInviteExpireArgs{LegionID: 1, InviterEID: 2, TargetEID: 3},
	})
	if err == nil || err.Error() != "boom" {
		t.Errorf("expected invoker error to propagate, got %v", err)
	}
	if inv.lastFn() != LuaFnLegionInviteExp {
		t.Errorf("expected CallGlobal(%s)", LuaFnLegionInviteExp)
	}

	// Nil-invoker branch.
	w2 := &LegionInviteExpireWorker{}
	if err := w2.Work(context.Background(), &river.Job[LegionInviteExpireArgs]{}); err != nil {
		t.Errorf("nil-invoker → nil, got %v", err)
	}
}

// TestDecodeListingIDPayloads covers all three branches of decodeListingID.
func TestDecodeListingIDPayloads(t *testing.T) {
	tests := []struct {
		name string
		in   []byte
		want int64
	}{
		{"empty", nil, 0},
		{"malformed", []byte(`{not-json`), 0},
		{"valid", []byte(`{"listing_id":42}`), 42},
		{"missing field", []byte(`{}`), 0},
	}
	for _, tc := range tests {
		if got := decodeListingID(tc.in); got != tc.want {
			t.Errorf("%s: got %d want %d", tc.name, got, tc.want)
		}
	}
}

// TestDefaultAsynqMuxWithInvoker ensures handlers forward to Lua when an
// invoker is present (all four kinds, covering the invoker != nil branches).
func TestDefaultAsynqMuxWithInvoker(t *testing.T) {
	inv := &recordingInvoker{}
	mux := DefaultAsynqMux(nil, inv)

	kinds := []struct {
		kind    string
		payload []byte
		wantFn  string
	}{
		{KindDailyReset, nil, LuaFnDailyReset},
		{KindPvpAPBatch, nil, LuaFnPvpAPBatch},
		{KindWorldBossSpawn, nil, LuaFnWorldBossSpawn},
		{KindAuctionExpire, []byte(`{"listing_id":7}`), LuaFnAuctionExpire},
	}
	for _, k := range kinds {
		task := asynq.NewTask(k.kind, k.payload)
		if err := mux.ProcessTask(context.Background(), task); err != nil {
			t.Errorf("ProcessTask(%s): %v", k.kind, err)
		}
		if inv.lastFn() != k.wantFn {
			t.Errorf("%s: expected Lua fn %s, got %s", k.kind, k.wantFn, inv.lastFn())
		}
	}
}

// TestSeasonPoolSwap covers the STORY-21 cron handler end-to-end:
//   1. payload encode/decode round-trip preserves the int64 season_seed
//   2. mux dispatch forwards LuaFnSeasonPoolSwap with the seed as arg[0]
//   3. nil-invoker branch returns nil (dev-environment passthrough)
func TestSeasonPoolSwap(t *testing.T) {
	// Case 1: round-trip — encode {"season_seed":N} then decode == N.
	// Covers both the canonical cron payload shape and the empty/malformed
	// fall-through (decodeSeasonSeed → 0).
	t.Run("payload round-trip", func(t *testing.T) {
		cases := []struct {
			name string
			in   []byte
			want int64
		}{
			{"empty", nil, 0},
			{"malformed", []byte(`{not-json`), 0},
			{"missing field", []byte(`{}`), 0},
			{"valid zero", []byte(`{"season_seed":0}`), 0},
			{"valid mid", []byte(`{"season_seed":2934}`), 2934},
			{"valid max-uint32", []byte(`{"season_seed":4294967295}`), 4294967295},
		}
		for _, tc := range cases {
			if got := decodeSeasonSeed(tc.in); got != tc.want {
				t.Errorf("%s: got %d want %d", tc.name, got, tc.want)
			}
		}

		// Sanity: the encoder a future producer would use also round-trips.
		raw, err := json.Marshal(struct {
			SeasonSeed int64 `json:"season_seed"`
		}{SeasonSeed: 2934})
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		if got := decodeSeasonSeed(raw); got != 2934 {
			t.Errorf("encode-then-decode: got %d want 2934", got)
		}
	})

	// Case 2: handler forwards the decoded seed verbatim into Lua via
	// LuaFnSeasonPoolSwap. Asserts both the function name and the single
	// argument so a future refactor that re-orders arguments fails loudly.
	t.Run("dispatch forwards seed", func(t *testing.T) {
		inv := &recordingInvoker{}
		mux := DefaultAsynqMux(nil, inv)
		task := asynq.NewTask(KindSeasonPoolSwap, []byte(`{"season_seed":2934}`))
		if err := mux.ProcessTask(context.Background(), task); err != nil {
			t.Fatalf("ProcessTask: %v", err)
		}
		if inv.lastFn() != LuaFnSeasonPoolSwap {
			t.Errorf("expected fn=%s, got %s", LuaFnSeasonPoolSwap, inv.lastFn())
		}
		inv.mu.Lock()
		args := inv.calls[len(inv.calls)-1].args
		inv.mu.Unlock()
		if len(args) != 1 {
			t.Fatalf("expected 1 arg, got %d", len(args))
		}
		seed, ok := args[0].(int64)
		if !ok {
			t.Fatalf("arg[0] type: want int64, got %T", args[0])
		}
		if seed != 2934 {
			t.Errorf("arg[0] value: want 2934, got %d", seed)
		}
	})

	// Case 3: nil invoker = dev-environment passthrough; handler must NOT
	// panic and must return nil so asynq marks the task processed.
	t.Run("nil invoker passthrough", func(t *testing.T) {
		mux := DefaultAsynqMux(nil, nil)
		task := asynq.NewTask(KindSeasonPoolSwap, []byte(`{"season_seed":1}`))
		if err := mux.ProcessTask(context.Background(), task); err != nil {
			t.Errorf("nil-invoker dispatch: want nil, got %v", err)
		}
	})
}

// TestEnqueueKindInNilSafe covers both the delay-≤-0 fall-through and the
// nil-asynq short-circuit of EnqueueKindIn.
func TestEnqueueKindInNilSafe(t *testing.T) {
	b, err := New(context.Background(), Config{})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if err := b.EnqueueKindIn(context.Background(), "k", []byte(`{}`), 0); err != nil {
		t.Errorf("delay=0 on disabled bundle: %v", err)
	}
	if err := b.EnqueueKindIn(context.Background(), "k", []byte(`{}`), time.Second); err != nil {
		t.Errorf("delay>0 on disabled bundle: %v", err)
	}
}

// TestNilBundleAccessors pins all accessor nil-safety.
func TestNilBundleAccessors(t *testing.T) {
	var b *Bundle
	if b.RiverClient() != nil {
		t.Error("RiverClient on nil bundle must be nil")
	}
	if b.AsynqClient() != nil {
		t.Error("AsynqClient on nil bundle must be nil")
	}
	if b.AsynqScheduler() != nil {
		t.Error("AsynqScheduler on nil bundle must be nil")
	}
	if _, err := b.EnqueueAsynq(context.Background(), asynq.NewTask("k", nil)); err != nil {
		t.Errorf("EnqueueAsynq on nil bundle: %v", err)
	}
	if id, err := b.RegisterCron("@every 1m", asynq.NewTask("k", nil)); err != nil || id != "" {
		t.Errorf("RegisterCron on nil bundle: id=%q err=%v", id, err)
	}
	if err := b.EnqueueKind(context.Background(), "k", nil); err != nil {
		t.Errorf("EnqueueKind on nil bundle: %v", err)
	}
	if err := b.EnqueueKindIn(context.Background(), "k", nil, time.Second); err != nil {
		t.Errorf("EnqueueKindIn on nil bundle: %v", err)
	}
}
