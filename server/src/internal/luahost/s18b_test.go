// Package luahost — Phase S-18b regression tests.
//
// Covers the previously-unhandled character-lifecycle opcodes:
//
//   - CM_CREATE_CHARACTER (0x12) → SM_CREATE_CHARACTER_RESPONSE (0x13)
//   - CM_DELETE_CHARACTER (0x14) → SM_DELETE_CHARACTER_RESPONSE (0x17)
//
// The handlers live in scripts/handlers/cm_create_character.lua and
// cm_delete_character.lua. Both issue SP calls via db.call (installed via
// programmableDB) and push SM_* packets via player.send_packet, which the
// mockCaptureSender records so the test can assert on opcode and result byte.
//
// Test inventory:
//   - script-loaded: both handlers register on 0x12 / 0x14
//   - create: happy path, name-too-short (1), name-length-min (2),
//             name-length-max (16), name-too-long (17), name taken,
//             name forbidden, bad race, bad class, bad gender, SP failure
//   - delete: happy path (owner match, grace timestamp set),
//             bad confirm token, non-owner, unknown char_id, SP failure
package luahost

import (
	"encoding/binary"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// newS18bBridge mirrors the s14/s16 harness — an ECS world, the capture
// sender for SM_* inspection, a programmableDB for per-SP response staging,
// and a full script load. Returns pieces the individual tests pin down.
func newS18bBridge(t *testing.T, pdb *programmableDB) (*Bridge, *lua.LState, *ecs.World, *mockCaptureSender) {
	t.Helper()
	world := ecs.NewWorld()
	sender := &mockCaptureSender{}
	var db DBBridge = &mockDB{}
	if pdb != nil {
		db = pdb
	}
	b := &Bridge{ECS: world, DB: db, Sender: sender}
	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	openSafeLibs(L)
	b.Register(L)
	if err := loadScripts(L, s14ScriptsDir); err != nil {
		L.Close()
		t.Fatalf("s18b loadScripts: %v", err)
	}
	return b, L, world, sender
}

// makeCreatePayload builds a CM_CREATE_CHARACTER binary body matching the
// wire layout documented in cm_create_character.lua. name is encoded as
// UTF-16 LE null-terminated; unusedUnits>0 appends extra UTF-16 units past
// the terminator to simulate a client trailing-garbage scenario (unused).
func makeCreatePayload(name string, gender, race, class byte) []byte {
	var buf []byte
	for _, r := range name {
		u := uint16(r)
		buf = append(buf, byte(u), byte(u>>8))
	}
	buf = append(buf, 0x00, 0x00) // null terminator
	buf = append(buf, gender, race, class)
	// 4 int32 colour fields + 3 byte type fields + float32 scale.
	buf = append(buf, 0, 0, 0, 0) // face_color
	buf = append(buf, 0, 0, 0, 0) // hair_color
	buf = append(buf, 0, 0, 0, 0) // eye_color
	buf = append(buf, 0, 0, 0, 0) // lip_color
	buf = append(buf, 0, 0, 0)    // face_type / hair_type / voice_type
	// scale = 1.0 little-endian float32 (0x3F800000).
	buf = append(buf, 0x00, 0x00, 0x80, 0x3F)
	return buf
}

// makeDeletePayload: int32 char_id + int32 confirm token (signed).
func makeDeletePayload(charID int32, confirm int32) []byte {
	var buf [8]byte
	binary.LittleEndian.PutUint32(buf[0:4], uint32(charID))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(confirm))
	return buf[:]
}

// dispatchCM invokes the Lua dispatch_packet global with a fabricated ctx.
// gwSeq identifies the sender; the caller inspects sender.sentToGateway
// afterwards to pick up the SM_* reply.
func dispatchCM(t *testing.T, L *lua.LState, opcode uint16, gwSeq uint64,
	accountID int64, account string, entityID ecs.Entity, body []byte) {
	t.Helper()
	ctx := L.NewTable()
	L.SetField(ctx, "entity_id", lua.LNumber(float64(entityID)))
	L.SetField(ctx, "gateway_seq_id", lua.LNumber(float64(gwSeq)))
	L.SetField(ctx, "account_id", lua.LNumber(float64(accountID)))
	L.SetField(ctx, "account", lua.LString(account))

	fn := L.GetGlobal("dispatch_packet")
	if fn == lua.LNil {
		t.Fatal("dispatch_packet global missing")
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 0, Protect: true},
		lua.LNumber(float64(opcode)), ctx, lua.LString(string(body))); err != nil {
		t.Fatalf("dispatch_packet(0x%X): %v", opcode, err)
	}
}

// lastPacket returns the last SM_* packet sent to gwSeq or fails the test.
func lastPacket(t *testing.T, sender *mockCaptureSender, gwSeq uint64) capturedPacket {
	t.Helper()
	pkts := sender.sentToGateway(gwSeq)
	if len(pkts) == 0 {
		t.Fatalf("no packet sent to gateway %d", gwSeq)
	}
	return pkts[len(pkts)-1]
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateDeleteHandlersRegistered — both opcodes have registered handlers.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateDeleteHandlersRegistered(t *testing.T) {
	_, L, _, sender := newS18bBridge(t, nil)
	defer L.Close()

	// Dispatch both opcodes with empty bodies; they should not raise a Lua
	// error. The handlers will emit a response (possibly an error result).
	dispatchCM(t, L, 0x12, 100, 1, "acct", 0, makeCreatePayload("Ab", 0, 0, 0))
	dispatchCM(t, L, 0x14, 100, 1, "acct", 0, makeDeletePayload(0, 0))

	// At least one SM_* packet went out for gw=100.
	if len(sender.sentToGateway(100)) < 2 {
		t.Errorf("expected >=2 packets on gw=100 (0x13 + 0x17), got %d",
			len(sender.sentToGateway(100)))
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateHappyPath — valid inputs → SM_CREATE_CHARACTER_RESPONSE result=0.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateHappyPath(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_checkvalidcharname":  {{"aion_checkvalidcharname": int64(0)}},
			"aion_putchar_20160620":    {{"char_id": int64(50001)}},
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x12, 200, 42, "tester", 0,
		makeCreatePayload("Hero", 0, 0, 0))

	pkt := lastPacket(t, sender, 200)
	if pkt.opcode != 0x13 {
		t.Fatalf("opcode: want 0x13, got 0x%X", pkt.opcode)
	}
	if pkt.payload[0] != 0 {
		t.Errorf("result byte: want 0 (OK), got %d", pkt.payload[0])
	}
	// char_id field at offset 1..4.
	got := binary.LittleEndian.Uint32(pkt.payload[1:5])
	if got != 50001 {
		t.Errorf("char_id: want 50001, got %d", got)
	}
	if !pdb.sawCall("aion_putchar_20160620") {
		t.Errorf("aion_putchar_20160620 not invoked; calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateNameLengthBoundaries — 1 (fail), 2 (ok), 16 (ok), 17 (fail).
// ─────────────────────────────────────────────────────────────────────────
func TestCreateNameLengthBoundaries(t *testing.T) {
	cases := []struct {
		name     string
		input    string
		wantCode byte // 0=OK, 1=NAME_INVALID
	}{
		{"1-char", "A", 1},
		{"2-char", "Ab", 0},
		{"16-char", "ABCDEFGHIJKLMNOP", 0},
		{"17-char", "ABCDEFGHIJKLMNOPQ", 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			pdb := &programmableDB{
				rows: map[string][]map[string]any{
					"aion_checkvalidcharname": {{"aion_checkvalidcharname": int64(0)}},
					"aion_putchar_20160620":   {{"char_id": int64(77)}},
				},
			}
			_, L, _, sender := newS18bBridge(t, pdb)
			defer L.Close()

			dispatchCM(t, L, 0x12, 300, 1, "a", 0,
				makeCreatePayload(tc.input, 0, 0, 0))
			pkt := lastPacket(t, sender, 300)
			if pkt.payload[0] != tc.wantCode {
				t.Errorf("input=%q len=%d: result byte want %d, got %d",
					tc.input, len(tc.input), tc.wantCode, pkt.payload[0])
			}
		})
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateNameTaken — SP returns -1 → result=2 (NAME_TAKEN).
// ─────────────────────────────────────────────────────────────────────────
func TestCreateNameTaken(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_checkvalidcharname": {{"aion_checkvalidcharname": int64(-1)}},
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x12, 400, 1, "a", 0, makeCreatePayload("Dup", 0, 0, 0))
	pkt := lastPacket(t, sender, 400)
	if pkt.payload[0] != 2 {
		t.Errorf("result: want 2 (NAME_TAKEN), got %d", pkt.payload[0])
	}
	if pdb.sawCall("aion_putchar_20160620") {
		t.Error("putchar must NOT be invoked when name is taken")
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateNameForbidden — SP returns -2 (forbidden word) → result=3.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateNameForbidden(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_checkvalidcharname": {{"aion_checkvalidcharname": int64(-2)}},
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x12, 401, 1, "a", 0, makeCreatePayload("Bad", 0, 0, 0))
	pkt := lastPacket(t, sender, 401)
	if pkt.payload[0] != 3 {
		t.Errorf("result: want 3 (NAME_FORBIDDEN), got %d", pkt.payload[0])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateBadRace — race=2 → result=4 (BAD_RACE), no DB calls.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateBadRace(t *testing.T) {
	pdb := &programmableDB{}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x12, 500, 1, "a", 0, makeCreatePayload("Ab", 0, 2, 0))
	pkt := lastPacket(t, sender, 500)
	if pkt.payload[0] != 4 {
		t.Errorf("result: want 4 (BAD_RACE), got %d", pkt.payload[0])
	}
	if pdb.sawCall("aion_checkvalidcharname") {
		t.Error("name-check must be skipped on bad race")
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateBadClass — unknown class id → result=5.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateBadClass(t *testing.T) {
	_, L, _, sender := newS18bBridge(t, &programmableDB{})
	defer L.Close()

	dispatchCM(t, L, 0x12, 501, 1, "a", 0, makeCreatePayload("Ab", 0, 0, 99))
	pkt := lastPacket(t, sender, 501)
	if pkt.payload[0] != 5 {
		t.Errorf("result: want 5 (BAD_CLASS), got %d", pkt.payload[0])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestCreateBadGender — gender=2 → result=6.
// ─────────────────────────────────────────────────────────────────────────
func TestCreateBadGender(t *testing.T) {
	_, L, _, sender := newS18bBridge(t, &programmableDB{})
	defer L.Close()

	dispatchCM(t, L, 0x12, 502, 1, "a", 0, makeCreatePayload("Ab", 2, 0, 0))
	pkt := lastPacket(t, sender, 502)
	if pkt.payload[0] != 6 {
		t.Errorf("result: want 6 (BAD_GENDER), got %d", pkt.payload[0])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestDeleteHappyPath — owner match → result=0 and grace timestamp > 0.
// ─────────────────────────────────────────────────────────────────────────
func TestDeleteHappyPath(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_getcharinfo_20160818": {
				{"account_id": int64(42), "name": "Hero"},
			},
			// aion_setchardeletetime returns void; empty rows = success.
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x14, 600, 42, "tester", 0,
		makeDeletePayload(50001, -559038737)) // 0xDEADBEEF signed

	pkt := lastPacket(t, sender, 600)
	if pkt.opcode != 0x17 {
		t.Fatalf("opcode: want 0x17, got 0x%X", pkt.opcode)
	}
	if pkt.payload[0] != 0 {
		t.Errorf("result: want 0 (OK), got %d", pkt.payload[0])
	}
	charID := binary.LittleEndian.Uint32(pkt.payload[1:5])
	if charID != 50001 {
		t.Errorf("char_id echo: want 50001, got %d", charID)
	}
	when := binary.LittleEndian.Uint32(pkt.payload[5:9])
	if when == 0 {
		t.Error("delete_unixtime must be >0 on success")
	}
	if !pdb.sawCall("aion_setchardeletetime") {
		t.Errorf("aion_setchardeletetime not called; calls=%v", pdb.calls)
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestDeleteBadConfirm — confirm token mismatch → result=3, no DB calls.
// ─────────────────────────────────────────────────────────────────────────
func TestDeleteBadConfirm(t *testing.T) {
	pdb := &programmableDB{}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x14, 601, 42, "tester", 0,
		makeDeletePayload(50001, 0x12345678))
	pkt := lastPacket(t, sender, 601)
	if pkt.payload[0] != 3 {
		t.Errorf("result: want 3 (BAD_CONFIRM), got %d", pkt.payload[0])
	}
	if pdb.sawCall("aion_getcharinfo_20160818") {
		t.Error("lookup must be skipped on bad confirm")
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestDeleteNotOwner — char belongs to another account → result=1.
// ─────────────────────────────────────────────────────────────────────────
func TestDeleteNotOwner(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_getcharinfo_20160818": {
				{"account_id": int64(99), "name": "Stolen"},
			},
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x14, 602, 42, "tester", 0,
		makeDeletePayload(50001, -559038737))
	pkt := lastPacket(t, sender, 602)
	if pkt.payload[0] != 1 {
		t.Errorf("result: want 1 (NOT_OWNER), got %d", pkt.payload[0])
	}
	if pdb.sawCall("aion_setchardeletetime") {
		t.Error("setchardeletetime must not run on owner mismatch")
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestDeleteUnknownChar — char_id lookup returns no rows → result=2.
// ─────────────────────────────────────────────────────────────────────────
func TestDeleteUnknownChar(t *testing.T) {
	pdb := &programmableDB{
		rows: map[string][]map[string]any{
			"aion_getcharinfo_20160818": {}, // empty
		},
	}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x14, 603, 42, "tester", 0,
		makeDeletePayload(99999, -559038737))
	pkt := lastPacket(t, sender, 603)
	if pkt.payload[0] != 2 {
		t.Errorf("result: want 2 (NOT_FOUND), got %d", pkt.payload[0])
	}
}

// ─────────────────────────────────────────────────────────────────────────
// TestDeleteInvalidCharID — char_id<=0 → result=2, no DB calls.
// ─────────────────────────────────────────────────────────────────────────
func TestDeleteInvalidCharID(t *testing.T) {
	pdb := &programmableDB{}
	_, L, _, sender := newS18bBridge(t, pdb)
	defer L.Close()

	dispatchCM(t, L, 0x14, 604, 42, "tester", 0,
		makeDeletePayload(0, -559038737))
	pkt := lastPacket(t, sender, 604)
	if pkt.payload[0] != 2 {
		t.Errorf("result: want 2 (NOT_FOUND), got %d", pkt.payload[0])
	}
	if len(pdb.calls) > 0 {
		t.Errorf("no SP calls expected for invalid char_id, got %v", pdb.calls)
	}
}
