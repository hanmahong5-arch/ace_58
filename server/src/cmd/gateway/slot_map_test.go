package main

import (
	"bytes"
	"encoding/binary"
	"testing"
)

// 187 (CM_ENTER_WORLD) 5.8 客户端发 0B payload；翻译应注入 session 的
// SelectedCharID 作 4B LE 头部，Lua opcode = 0x15。
func TestTranslateClientCM58_EnterWorldInjectsCharID(t *testing.T) {
	sess := &Session{}
	sess.setSelectedCharID(424242)

	luaOp, rewritten, ok := translateClientCM58(gameSlot_CM_ENTER_WORLD, []byte{}, sess)

	if !ok {
		t.Fatalf("expected mapped=true for slot 187, got false")
	}
	if luaOp != 0x15 {
		t.Fatalf("expected luaOp=0x15 (CM_ENTER_WORLD), got 0x%x", luaOp)
	}
	if len(rewritten) != 4 {
		t.Fatalf("expected 4B rewritten payload, got %d bytes", len(rewritten))
	}
	got := binary.LittleEndian.Uint32(rewritten)
	if int32(got) != 424242 {
		t.Fatalf("expected injected char_id=424242, got %d", int32(got))
	}
}

// 215 (CM_CHARACTER_LIST) 5.8 跟 4.8 payload 形状一致；翻译应保持 payload
// 不变并产 Lua opcode 0x11。
func TestTranslateClientCM58_CharacterListPassThrough(t *testing.T) {
	sess := &Session{}
	original := []byte{0x01, 0x02, 0x03, 0x04}

	luaOp, rewritten, ok := translateClientCM58(gameSlot_CM_CHARACTER_LIST, original, sess)

	if !ok {
		t.Fatalf("expected mapped=true for slot 215, got false")
	}
	if luaOp != 0x11 {
		t.Fatalf("expected luaOp=0x11 (CM_CHARACTER_LIST), got 0x%x", luaOp)
	}
	if !bytes.Equal(rewritten, original) {
		t.Fatalf("expected payload unchanged for slot 215, got %x", rewritten)
	}
}

// 未映射 slot（例如 IN_GAME 心跳 92/107）应返回 ok=false，调用方按原 slot 转发。
func TestTranslateClientCM58_UnmappedSlot(t *testing.T) {
	sess := &Session{}
	original := []byte{0xDE, 0xAD, 0xBE, 0xEF}

	luaOp, rewritten, ok := translateClientCM58(92, original, sess)

	if ok {
		t.Fatalf("expected mapped=false for unmapped slot 92, got true (luaOp=0x%x)", luaOp)
	}
	if luaOp != 0 {
		t.Fatalf("expected luaOp=0 when unmapped, got 0x%x", luaOp)
	}
	if !bytes.Equal(rewritten, original) {
		t.Fatalf("expected payload unchanged on unmapped, got %x", rewritten)
	}
}

// SelectedCharID=0 的边缘（CHARACTER_LIST 阶段还没填）：translate 仍 OK，但注入 0。
// Lua handler 会 log "char not found" 并 early return，不应崩溃 gateway。
func TestTranslateClientCM58_EnterWorldZeroCharID(t *testing.T) {
	sess := &Session{} // SelectedCharID 默认 0

	luaOp, rewritten, ok := translateClientCM58(gameSlot_CM_ENTER_WORLD, []byte{}, sess)

	if !ok || luaOp != 0x15 || len(rewritten) != 4 {
		t.Fatalf("translate failed: ok=%v op=0x%x len=%d", ok, luaOp, len(rewritten))
	}
	got := binary.LittleEndian.Uint32(rewritten)
	if got != 0 {
		t.Fatalf("expected zero char_id when not set, got %d", got)
	}
}

// 已有 payload 的 5.8 ENTER_WORLD（虽然实测是 0B，但 wire 不保证）：注入头部后
// 原 payload 应被保留在尾部。
func TestTranslateClientCM58_EnterWorldPreservesTrailingPayload(t *testing.T) {
	sess := &Session{}
	sess.setSelectedCharID(7777)
	trailing := []byte{0xAA, 0xBB, 0xCC}

	luaOp, rewritten, ok := translateClientCM58(gameSlot_CM_ENTER_WORLD, trailing, sess)

	if !ok || luaOp != 0x15 {
		t.Fatalf("translate failed: ok=%v op=0x%x", ok, luaOp)
	}
	if len(rewritten) != 4+len(trailing) {
		t.Fatalf("expected 4 (char_id) + %d (trailing) bytes, got %d",
			len(trailing), len(rewritten))
	}
	if binary.LittleEndian.Uint32(rewritten[0:4]) != 7777 {
		t.Fatalf("char_id not in head 4B")
	}
	if !bytes.Equal(rewritten[4:], trailing) {
		t.Fatalf("trailing payload corrupted: %x", rewritten[4:])
	}
}
