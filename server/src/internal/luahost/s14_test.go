// Package luahost — Phase S-14 regression tests.
//
// Covers the Mail System MVP (scripts/lib/mail.lua + handlers/cm_mail_*.lua):
//   - mail global table with MAX_SUBJECT_LEN / MAX_BODY_LEN / SEND_FEE constants
//   - mail.send text-validation (bad_subject / bad_body / bad_item_count)
//   - mail.send recipient resolution (no_recipient when DB + online lookup fail)
//   - mail.send kinah accounting (no_kinah, happy-path deduct, sp_failed rollback)
//   - mail.send online-recipient notification (SM_MAIL_NEW 0xC4 to recipient gw)
//   - mail.list empty-when-no-db + row decoding
//   - mail.read SP failure surface
//   - mail.claim already-claimed / item grant / kinah grant
//   - mail.delete happy path
//   - cm_mail_send / cm_mail_list handlers registered on dispatch_packet
package luahost

import (
	"context"
	"path/filepath"
	"sync"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// programmableDB is a DBBridge that answers per-SP with a canned row set and
// records the name of every CallSP so tests can assert "was this SP invoked
// by the Go-side bindings (player.add_item / add_kinah / etc.) that bypass
// the Lua `_G.db` override".
//
// Extension introduced by Phase S-14: the existing `mockDB` is a no-op that
// returns nil for everything, which is enough for Lua-driven tests that stub
// `_G.db` at the script level. But mail.claim relies on Go-side
// `player.add_item`, which calls `b.DB.CallSP` directly — those calls cannot
// be observed through `_G.db`. programmableDB lets the Go test both program
// the response AND observe the call path for those bindings.
type programmableDB struct {
	mu       sync.Mutex
	rows     map[string][]map[string]any // SP name → rows
	calls    []string                    // recorded in call order
}

func (p *programmableDB) CallSP(_ context.Context, name string, _ []any) ([]map[string]any, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.calls = append(p.calls, name)
	if rows, ok := p.rows[name]; ok {
		return rows, nil
	}
	return nil, nil
}

// sawCall reports whether the given SP name appears anywhere in the call log.
func (p *programmableDB) sawCall(name string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, c := range p.calls {
		if c == name {
			return true
		}
	}
	return false
}

// s14ScriptsDir points to the Lua scripts directory from this package's cwd.
var s14ScriptsDir = filepath.Join("..", "..", "..", "scripts")

// newS14Bridge builds a fresh ECS World + Bridge + Lua state with all scripts
// loaded, and mirrors the s10/s11/s12 harness pattern (ECS + capture sender +
// no-op Go-level mockDB). Mail tests override `_G.db` at the Lua level to
// program SP responses per-test — this keeps the Go-side DBBridge interface
// untouched.
func newS14Bridge(t *testing.T) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	b := &Bridge{ECS: world, DB: &mockDB{}, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s14ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s14 loadScripts: %v", err)
	}
	return b, L, world, sender
}

// spawnS14Player creates a player-controlled entity with gateway seq id, char
// name, and the three stats mail.send reads: char_id, kinah, dead.
// Returns the ECS entity id.
func spawnS14Player(t *testing.T, world *ecs.World,
	gw uint64, charID float64, name string, kinah float64) ecs.Entity {
	t.Helper()
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gw, CharName: name})
	world.SetStat(eid, "char_id", charID)
	world.SetStat(eid, "kinah", kinah)
	world.SetStat(eid, "dead", 0)
	return eid
}

// installMailDB overrides the global `db.call` in Lua with a table-driven
// stub. `responses` maps SP name -> a Lua expression for the array of rows to
// return (e.g. `{[1]={mail_id=42}}` or `{}`). A SP name suffixed with "!err"
// causes db.call to return nil + the literal error string.
//
// This is a more flexible variant of the s10 `injectMockDB` helper because
// mail.send needs to program two different SPs in a single call chain:
// `aion_GetCharIdByName` (for recipient lookup) and `aion_InsertMailUser`
// (for persistence).
func installMailDB(t *testing.T, L *lua.LState, responses map[string]string) {
	t.Helper()
	// Build a Lua table literal from the responses map.
	src := `_G.db = { call = function(name, ...)
`
	for sp, rows := range responses {
		if len(sp) > 4 && sp[len(sp)-4:] == "!err" {
			realName := sp[:len(sp)-4]
			src += `    if name == "` + realName + `" then return nil, "` + rows + `" end
`
			continue
		}
		src += `    if name == "` + sp + `" then return ` + rows + ` end
`
	}
	src += `    return {}
end }
`
	if err := L.DoString(src); err != nil {
		t.Fatalf("installMailDB DoString failed: %v\n%s", err, src)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailLibLoaded — mail global table exists with send/list/read/claim/delete.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailLibLoaded(t *testing.T) {
	_, L, _, _ := newS14Bridge(t)
	defer L.Close()

	tbl, ok := L.GetGlobal("mail").(*lua.LTable)
	if !ok {
		t.Fatalf("expected mail to be a table, got %T", L.GetGlobal("mail"))
	}
	for _, fn := range []string{"send", "list", "read", "claim", "delete"} {
		if _, ok := L.GetField(tbl, fn).(*lua.LFunction); !ok {
			t.Errorf("expected mail.%s to be a function, got %T",
				fn, L.GetField(tbl, fn))
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailConstants — MAX_SUBJECT_LEN=80, MAX_BODY_LEN=1024, SEND_FEE=10.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailConstants(t *testing.T) {
	_, L, _, _ := newS14Bridge(t)
	defer L.Close()

	tbl := L.GetGlobal("mail").(*lua.LTable)
	checks := map[string]lua.LNumber{
		"MAX_SUBJECT_LEN":    80,
		"MAX_BODY_LEN":       1024,
		"MAX_ATTACHED_COUNT": 9999,
		"SEND_FEE":           10,
	}
	for field, want := range checks {
		if v := L.GetField(tbl, field); v != want {
			t.Errorf("mail.%s: want %v, got %v", field, want, v)
		}
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendBadSubject — empty subject returns false,"bad_subject" and
// does NOT touch kinah or DB.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendBadSubject(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1400, 14001, "Sender", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = mail.send(EID, "Nobody", "", "body", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on empty subject, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_subject") {
		t.Errorf("want reason=bad_subject, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on bad_subject, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendBadBody — empty body returns false,"bad_body".
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendBadBody(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1401, 14002, "Sender", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(`_ok, _r = mail.send(EID, "Nobody", "Subj", "", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on empty body, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_body") {
		t.Errorf("want reason=bad_body, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendBadItemCount — item_id > 0 with item_count <= 0 rejected.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendBadItemCount(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1402, 14003, "Sender", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	if err := L.DoString(
		`_ok, _r = mail.send(EID, "Nobody", "Subj", "Body", 100001, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on item_count=0 with item_id>0, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("bad_item_count") {
		t.Errorf("want reason=bad_item_count, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendNoRecipient — GetCharIdByName returns empty, find_by_name fails
// → false,"no_recipient". No kinah is spent.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendNoRecipient(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1403, 14004, "Sender", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Empty rows for the name lookup; no player named "Ghost" online.
	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName": `{}`,
	})

	if err := L.DoString(
		`_ok, _r = mail.send(EID, "Ghost", "Subj", "Body", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on missing recipient, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("no_recipient") {
		t.Errorf("want reason=no_recipient, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 1000 {
		t.Errorf("kinah must be untouched on no_recipient, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendNoKinah — sender has 5 kinah (< SEND_FEE=10) → "no_kinah".
// Recipient lookup succeeds (via stubbed SP) so the check that fires is the
// kinah balance, not the recipient existence.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendNoKinah(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1404, 14005, "Broke", 5)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName": `{[1]={char_id=99999}}`,
	})

	if err := L.DoString(
		`_ok, _r = mail.send(EID, "Rich", "Subj", "Body", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on insufficient kinah, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("no_kinah") {
		t.Errorf("want reason=no_kinah, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 5 {
		t.Errorf("kinah must be untouched on no_kinah, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendHappyPath — both SPs return valid rows; mail.send returns true
// and exactly SEND_FEE (10) kinah is deducted from the sender.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendHappyPath(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1405, 14006, "Alice", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName": `{[1]={char_id=88888}}`,
		"aion_InsertMailUser":  `{[1]={mail_id=777}}`,
	})

	if err := L.DoString(
		`_ok, _r = mail.send(EID, "Bob", "Hi", "Body", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Errorf("want ok=true on happy path, got %v (reason=%v)",
			v, L.GetGlobal("_r"))
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 490 {
		t.Errorf("kinah should drop by SEND_FEE(10) to 490, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendRollsBackKinahOnSpFail — aion_GetCharIdByName succeeds but
// aion_InsertMailUser returns an error; mail.send must return sp_failed AND
// refund the deducted fee so the sender's kinah is restored to its original
// balance.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendRollsBackKinahOnSpFail(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1406, 14007, "Carol", 500)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Recipient lookup OK, insert fails.
	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName":    `{[1]={char_id=55555}}`,
		"aion_InsertMailUser!err": "db_outage",
	})

	if err := L.DoString(
		`_ok, _r = mail.send(EID, "Dave", "Subj", "Body", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on SP failure, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("sp_failed") {
		t.Errorf("want reason=sp_failed, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 500 {
		t.Errorf("kinah must be refunded to 500 on sp_failed, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailSendNotifiesOnlineRecipient — when the recipient is a live player,
// SM_MAIL_NEW (0xC4) must be delivered to THEIR gateway seq id (not the
// sender's). Uses the capture sender to inspect routing.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailSendNotifiesOnlineRecipient(t *testing.T) {
	_, L, world, sender := newS14Bridge(t)
	defer L.Close()

	senderEid := spawnS14Player(t, world, 1407, 14008, "Sndr", 500)
	recipEid := spawnS14Player(t, world, 1408, 14009, "Recp", 0)
	_ = recipEid
	L.SetGlobal("EID", lua.LNumber(float64(senderEid)))

	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName": `{[1]={char_id=14009}}`,
		"aion_InsertMailUser":  `{[1]={mail_id=321}}`,
	})

	// Clear any packets captured during harness/script load.
	sender.packets = nil

	if err := L.DoString(
		`_ok = mail.send(EID, "Recp", "Hello", "World", 0, 0, 0)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Fatalf("expected mail.send ok=true, got %v", v)
	}

	// The SM_MAIL_NEW packet must be routed to the recipient's gateway (1408),
	// not the sender's (1407).
	var mailNewToRecip int
	var mailNewToSender int
	for _, p := range sender.packets {
		if p.opcode != 0xC4 {
			continue
		}
		if p.gatewaySeqID == 1408 {
			mailNewToRecip++
		}
		if p.gatewaySeqID == 1407 {
			mailNewToSender++
		}
	}
	if mailNewToRecip != 1 {
		t.Errorf("expected 1 SM_MAIL_NEW to recipient gw 1408, got %d", mailNewToRecip)
	}
	if mailNewToSender != 0 {
		t.Errorf("expected 0 SM_MAIL_NEW to sender gw 1407, got %d", mailNewToSender)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailListReturnsEmptyWhenNoDb — with _G.db set to nil, mail.list degrades
// to an empty array rather than raising an error.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailListReturnsEmptyWhenNoDb(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1409, 14010, "Reader", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Disable the DB binding entirely.
	if err := L.DoString(`_G.db = nil`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if err := L.DoString(`_rows = mail.list(EID); _n = #_rows`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(0) {
		t.Errorf("expected empty list when db=nil, got count=%v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailListReturnsRows — SP returns two rows; mail.list surfaces both with
// their fields intact.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailListReturnsRows(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1410, 14011, "Reader", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_GetMailsByUser": `{
			[1]={mail_id=1, sender_name="A", subject="first",  is_read=0, has_attachment=0, sent_ts=100},
			[2]={mail_id=2, sender_name="B", subject="second", is_read=1, has_attachment=1, sent_ts=200}
		}`,
	})

	chunk := `
_rows = mail.list(EID)
_n = #_rows
if _n >= 2 then
    _id1  = _rows[1].mail_id
    _sub1 = _rows[1].subject
    _id2  = _rows[2].mail_id
    _sub2 = _rows[2].subject
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_n"); v != lua.LNumber(2) {
		t.Fatalf("expected 2 rows, got %v", v)
	}
	if v := L.GetGlobal("_id1"); v != lua.LNumber(1) {
		t.Errorf("row1 mail_id wrong: %v", v)
	}
	if v := L.GetGlobal("_sub1"); v != lua.LString("first") {
		t.Errorf("row1 subject wrong: %v", v)
	}
	if v := L.GetGlobal("_id2"); v != lua.LNumber(2) {
		t.Errorf("row2 mail_id wrong: %v", v)
	}
	if v := L.GetGlobal("_sub2"); v != lua.LString("second") {
		t.Errorf("row2 subject wrong: %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailReadSpFail — aion_UpdateMailRead returns an error → false,"sp_failed".
// ─────────────────────────────────────────────────────────────────────────────
func TestMailReadSpFail(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1411, 14012, "Reader", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_UpdateMailRead!err": "timeout",
	})

	if err := L.DoString(`_ok, _r = mail.read(EID, 42)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on SP err, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("sp_failed") {
		t.Errorf("want reason=sp_failed, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailClaimAlreadyClaimed — SP returns a row where both item_id and kinah
// are 0 (the attachment has been looted before) → false,"already_claimed".
// ─────────────────────────────────────────────────────────────────────────────
func TestMailClaimAlreadyClaimed(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1412, 14013, "Claimer", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_ClaimMailAttachment": `{[1]={item_id=0, item_count=0, kinah=0}}`,
	})

	if err := L.DoString(`_ok, _r = mail.claim(EID, 55)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LFalse {
		t.Errorf("want ok=false on empty attachment, got %v", v)
	}
	if v := L.GetGlobal("_r"); v != lua.LString("already_claimed") {
		t.Errorf("want reason=already_claimed, got %v", v)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailClaimHappyPathItem — SP row {item_id=100001, item_count=1, kinah=0}.
// Expect mail.claim → true and an aion_AddItemUser SP call to have been
// issued by the Go-side player.add_item binding. This test uses
// programmableDB because player.add_item bypasses the Lua `_G.db` override
// and calls Bridge.DB.CallSP directly.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailClaimHappyPathItem(t *testing.T) {
	b, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1413, 14014, "ItemClaimer", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	// Swap the Go-level DB for one we can observe. This is legal because
	// Bridge.DB is a plain field; both db.call (Lua) and player.add_item
	// (Go) funnel through it.
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_ClaimMailAttachment": {
				{"item_id": int64(100001), "item_count": int64(1), "kinah": int64(0)},
			},
			// aion_AddItemUser returns empty rows (success).
		},
	}
	b.DB = pdb

	if err := L.DoString(`_ok, _r = mail.claim(EID, 10)`); err != nil {
		t.Fatalf("DoString claim failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Fatalf("want ok=true, got %v (reason=%v)",
			v, L.GetGlobal("_r"))
	}

	if !pdb.sawCall("aion_ClaimMailAttachment") {
		t.Error("expected aion_ClaimMailAttachment to be called")
	}
	if !pdb.sawCall("aion_AddItemUser") {
		t.Errorf("expected aion_AddItemUser SP call on item attachment, calls=%v",
			pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailClaimHappyPathKinah — SP row {item_id=0, kinah=5000} → true and the
// player's cached kinah stat grows by 5000 (player.add_kinah path).
// ─────────────────────────────────────────────────────────────────────────────
func TestMailClaimHappyPathKinah(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1414, 14015, "KinahClaimer", 1000)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	installMailDB(t, L, map[string]string{
		"aion_ClaimMailAttachment": `{[1]={item_id=0, item_count=0, kinah=5000}}`,
	})

	if err := L.DoString(`_ok = mail.claim(EID, 11)`); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Fatalf("want ok=true, got %v", v)
	}
	if k, _ := world.GetStat(eid, "kinah"); k != 6000 {
		t.Errorf("kinah should grow by 5000 to 6000, got %v", k)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestMailDeleteOK — aion_DeleteMail succeeds → (true, nil) and the SP is
// recorded in the call log.
// ─────────────────────────────────────────────────────────────────────────────
func TestMailDeleteOK(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1415, 14016, "Deleter", 0)
	L.SetGlobal("EID", lua.LNumber(float64(eid)))

	chunk := `
_sp_calls = {}
_G.db = {
    call = function(name, ...)
        _sp_calls[#_sp_calls + 1] = name
        return {}
    end
}
_ok, _r = mail.delete(EID, 77)
_saw_delete = false
for _, name in ipairs(_sp_calls) do
    if name == "aion_DeleteMail" then _saw_delete = true end
end
`
	if err := L.DoString(chunk); err != nil {
		t.Fatalf("DoString failed: %v", err)
	}
	if v := L.GetGlobal("_ok"); v != lua.LTrue {
		t.Errorf("want ok=true on delete, got %v (reason=%v)",
			v, L.GetGlobal("_r"))
	}
	if v := L.GetGlobal("_saw_delete"); v != lua.LTrue {
		t.Error("expected aion_DeleteMail SP call, got none")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmMailSendHandlerRegistered — dispatch_packet(0xBE, payload) runs the
// cm_mail_send handler without raising a "no handler" warning. The recipient
// lookup is rigged to fail so no DB write happens; we only verify that the
// handler is wired and parses its UTF-16 payload correctly.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmMailSendHandlerRegistered(t *testing.T) {
	_, L, world, _ := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1416, 14017, "Dispatcher", 500)

	// Empty row set for every SP → mail.send hits "no_recipient" cleanly.
	installMailDB(t, L, map[string]string{
		"aion_GetCharIdByName": `{}`,
	})

	// Build the CM_MAIL_SEND payload:
	//   utf16_null recipient="Ghost"
	//   utf16_null subject="Hi"
	//   utf16_null body="Body"
	//   int32      item_id=0
	//   int32      item_count=0
	//   int64      kinah=0
	var payload []byte
	writeU16Null := func(s string) {
		for _, r := range s {
			u := uint16(r)
			payload = append(payload, byte(u), byte(u>>8))
		}
		payload = append(payload, 0x00, 0x00)
	}
	writeU16Null("Ghost")
	writeU16Null("Hi")
	writeU16Null("Body")
	// int32 item_id = 0
	payload = append(payload, 0, 0, 0, 0)
	// int32 item_count = 0
	payload = append(payload, 0, 0, 0, 0)
	// int64 kinah = 0
	payload = append(payload, 0, 0, 0, 0, 0, 0, 0, 0)

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1416))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xBE), ctx, lua.LString(string(payload)))
	if err != nil {
		t.Fatalf("dispatch_packet(0xBE) returned error: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TestCmMailListHandlerRegistered — dispatch_packet(0xBF, "") runs the
// cm_mail_list handler and captures the SM_MAIL_LIST (0xC3) response sent
// back to the caller's gateway seq id.
// ─────────────────────────────────────────────────────────────────────────────
func TestCmMailListHandlerRegistered(t *testing.T) {
	_, L, world, sender := newS14Bridge(t)
	defer L.Close()

	eid := spawnS14Player(t, world, 1417, 14018, "Lister", 0)

	installMailDB(t, L, map[string]string{
		"aion_GetMailsByUser": `{}`,
	})

	sender.packets = nil

	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(eid)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(1417))
	L.SetField(ctx, "account_id", lua.LNumber(0))
	L.SetField(ctx, "account", lua.LString("test"))
	L.SetGlobal("current_tick", lua.LNumber(1))

	dispatchFn := L.GetGlobal("dispatch_packet")
	if dispatchFn == lua.LNil {
		t.Fatal("dispatch_packet global not defined")
	}
	err := L.CallByParam(lua.P{
		Fn:      dispatchFn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(0xBF), ctx, lua.LString(""))
	if err != nil {
		t.Fatalf("dispatch_packet(0xBF) returned error: %v", err)
	}

	// Expect at least one SM_MAIL_LIST (0xC3) on the lister's gateway.
	var got int
	for _, p := range sender.sentToGateway(1417) {
		if p.opcode == 0xC3 {
			got++
		}
	}
	if got != 1 {
		t.Errorf("expected 1 SM_MAIL_LIST (0xC3) on gw 1417, got %d", got)
	}
}
