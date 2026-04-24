// Package luahost — Phase S-18 regression tests.
//
// Covers the aion_settleauction rewire in scripts/events/on_auction_expire.lua:
//
//   - on_auction_expire invokes db.call("aion_settleauction", listing_id)
//     exactly once per call, regardless of the SP's outcome_code
//   - outcome_code 0 (no_bids)       → log.info at INFO level
//   - outcome_code 1 (sold)          → log.info at INFO level
//   - outcome_code 2 (already_settled) → log.info at INFO level (safe retry)
//   - outcome_code 3 (missing)       → log.warn at WARN level
//   - SP returning (nil, err) surfaces a warn log and does NOT crash
//   - SP returning empty rows surfaces an info log and does NOT crash
//   - db=nil degrades to a single warn log without any SP call
//
// The tests override _G.db at the Lua level with a counting stub so we can
// assert the exact number of SP invocations; the Bridge logger is redirected
// to a captureHandler so we can inspect log levels.
package luahost

import (
	"context"
	"log/slog"
	"sync"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// captureHandler is a minimal slog.Handler that appends every record's level
// and message to an in-memory slice. Tests assert on slice contents to verify
// both the Lua log call order and the chosen severity per outcome_code.
type captureHandler struct {
	mu      sync.Mutex
	records []capturedLog
}

type capturedLog struct {
	Level slog.Level
	Msg   string
}

func (h *captureHandler) Enabled(_ context.Context, _ slog.Level) bool { return true }
func (h *captureHandler) Handle(_ context.Context, r slog.Record) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.records = append(h.records, capturedLog{Level: r.Level, Msg: r.Message})
	return nil
}
func (h *captureHandler) WithAttrs(_ []slog.Attr) slog.Handler { return h }
func (h *captureHandler) WithGroup(_ string) slog.Handler      { return h }

// last returns the last recorded log entry, or a zero value if empty.
func (h *captureHandler) last() capturedLog {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.records) == 0 {
		return capturedLog{}
	}
	return h.records[len(h.records)-1]
}

func (h *captureHandler) count() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.records)
}

// newS18State wires a Bridge whose Lua `log` table writes to the capture
// handler, then loads the full scripts tree. The returned counter is nil
// until the test installs a stub db via installSettleDB.
func newS18State(t *testing.T) (*lua.LState, *captureHandler) {
	t.Helper()
	h := &captureHandler{}
	bridge := &Bridge{
		ECS:    ecs.NewWorld(),
		DB:     &mockDB{},
		Sender: &mockSender{},
		Logger: slog.New(h),
	}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	bridge.Register(L)
	if err := loadScripts(L, scriptsDir); err != nil {
		L.Close()
		t.Fatalf("loadScripts: %v", err)
	}
	return L, h
}

// installSettleDB rewrites _G.db.call to return a single canned row from the
// aion_settleauction SP and to count invocations. Returns a Lua variable
// name the test can query to read the counter. Non-matching SP names return
// an empty table (the auction library's default "no-op" behaviour).
func installSettleDB(t *testing.T, L *lua.LState, returnRowSrc string) {
	t.Helper()
	src := `
		_settle_calls = 0
		_G.db = { call = function(name, ...)
			if name == "aion_settleauction" then
				_settle_calls = _settle_calls + 1
				return ` + returnRowSrc + `
			end
			return {}
		end }
	`
	if err := L.DoString(src); err != nil {
		t.Fatalf("installSettleDB: %v", err)
	}
}

func settleCallCount(t *testing.T, L *lua.LState) int {
	t.Helper()
	n, ok := L.GetGlobal("_settle_calls").(lua.LNumber)
	if !ok {
		t.Fatalf("_settle_calls missing")
	}
	return int(n)
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireNoBids — outcome_code=0 logs at INFO, one SP call.
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireNoBids(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	installSettleDB(t, L,
		`{ { winner_cid=0, seller_cid=5001, item_id=110000001,
		     item_count=1, final_bid=0, outcome_code=0 } }`)

	if err := L.DoString(`on_auction_expire(9999999001)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected 1 SP call, got %d", got)
	}
	if h.count() == 0 || h.last().Level != slog.LevelInfo {
		t.Errorf("expected INFO log, got %+v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireSold — outcome_code=1 logs at INFO, one SP call.
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireSold(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	installSettleDB(t, L,
		`{ { winner_cid=7001, seller_cid=5001, item_id=110000001,
		     item_count=1, final_bid=250000, outcome_code=1 } }`)

	if err := L.DoString(`on_auction_expire(9999999002)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected 1 SP call, got %d", got)
	}
	if h.last().Level != slog.LevelInfo {
		t.Errorf("expected INFO log, got %v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireAlreadySettled — outcome_code=2 is idempotent (INFO).
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireAlreadySettled(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	installSettleDB(t, L,
		`{ { winner_cid=0, seller_cid=0, item_id=0,
		     item_count=0, final_bid=0, outcome_code=2 } }`)

	if err := L.DoString(`on_auction_expire(9999999003)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected 1 SP call, got %d", got)
	}
	if h.last().Level != slog.LevelInfo {
		t.Errorf("already_settled must log at INFO, got %v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireMissing — outcome_code=3 escalates to WARN.
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireMissing(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	installSettleDB(t, L,
		`{ { winner_cid=0, seller_cid=0, item_id=0,
		     item_count=0, final_bid=0, outcome_code=3 } }`)

	if err := L.DoString(`on_auction_expire(9999999004)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected 1 SP call, got %d", got)
	}
	if h.last().Level != slog.LevelWarn {
		t.Errorf("missing listing must log at WARN, got %v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireSPError — (nil, err) tuple logs warn, no crash.
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireSPError(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	if err := L.DoString(`
		_settle_calls = 0
		_G.db = { call = function(name, ...)
			if name == "aion_settleauction" then
				_settle_calls = _settle_calls + 1
				return nil, "db_outage"
			end
			return {}
		end }
	`); err != nil {
		t.Fatalf("install err-stub: %v", err)
	}
	if err := L.DoString(`on_auction_expire(9999999005)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected 1 SP call, got %d", got)
	}
	if h.last().Level != slog.LevelWarn {
		t.Errorf("SP error must log at WARN, got %v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireNoDB — db=nil degrades safely with a single WARN log
// and zero SP calls (counter never incremented).
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireNoDB(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	if err := L.DoString(`_settle_calls = 0; _G.db = nil`); err != nil {
		t.Fatalf("nil db: %v", err)
	}
	if err := L.DoString(`on_auction_expire(9999999006)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 0 {
		t.Errorf("expected 0 SP calls with nil db, got %d", got)
	}
	if h.last().Level != slog.LevelWarn {
		t.Errorf("nil db must log at WARN, got %v", h.last())
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestOnAuctionExpireEmptyRows — SP returning an empty table logs INFO and
// does not call the SP again (no auto-retry).
// ─────────────────────────────────────────────────────────────────────────
func TestOnAuctionExpireEmptyRows(t *testing.T) {
	L, h := newS18State(t)
	defer L.Close()
	installSettleDB(t, L, `{}`)

	if err := L.DoString(`on_auction_expire(9999999007)`); err != nil {
		t.Fatalf("DoString: %v", err)
	}
	if got := settleCallCount(t, L); got != 1 {
		t.Errorf("expected exactly 1 SP call (no retry), got %d", got)
	}
	if h.last().Level != slog.LevelInfo {
		t.Errorf("empty rows should log at INFO, got %v", h.last())
	}
}
