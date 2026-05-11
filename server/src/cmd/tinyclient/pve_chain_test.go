// Round 11 C8 — tinyclient PvE 链编解码单元测试。
//
// 这些测试不依赖任何 5 进程拓扑或网络 IO，只校验：
//
//  1. encodeCreateCharacter 的字段顺序与 cm_create_character.lua 期待一致
//     （utf16_null + 3byte + 4int32 + 3byte + float32 = 字段读序）
//  2. parseCharacterList / parseCreateCharResp 能往返自己 encode 的字节
//  3. parseLootItemlist 能从一个手工构造的 SM_LOOT_ITEMLIST 拿到 stones 与
//     forge_id（=> 命题验证最关键路径，在 server 端 SM_LOOT 接通前先跑通解析）
//  4. CM_USE_SKILL 的 9 字节布局正确
//
// 运行：cd D:/拾光ai/ACE_5.8/server/src && go test ./cmd/tinyclient/...
package main

import (
	"encoding/binary"
	"testing"
)

// ---------------------------------------------------------------------------
// TestEncodeCMCreateCharacter
// 校验 CM_CREATE_CHARACTER 编码与 cm_create_character.lua 字段读序一致。
// ---------------------------------------------------------------------------
func TestEncodeCMCreateCharacter(t *testing.T) {
	// "Sg42" 是 4 个 ASCII 字符，UTF-16 LE = 8 字节 + 2 字节 null
	got := encodeCreateCharacter("Sg42", 0 /*M*/, 1 /*Asmodian*/, 2 /*Mage*/)

	// 拆 utf16 段
	if len(got) < 10 {
		t.Fatalf("encoded too short: %d", len(got))
	}
	wantUTF16 := []byte{
		'S', 0, 'g', 0, '4', 0, '2', 0, 0, 0,
	}
	for i, b := range wantUTF16 {
		if got[i] != b {
			t.Errorf("utf16 byte %d: got 0x%02X want 0x%02X", i, got[i], b)
		}
	}

	off := 10 // 之后是 gender/race/class
	if got[off] != 0 || got[off+1] != 1 || got[off+2] != 2 {
		t.Errorf("gender/race/class wrong: got %v want [0 1 2]", got[off:off+3])
	}
	off += 3

	// 4 个 int32 颜色字段（按编码顺序: face_color, hair_color, eye_color, lip_color）
	wantColors := []uint32{0x00FFD0B8, 0x00808080, 0x00404060, 0x00C04040}
	for i, want := range wantColors {
		got32 := binary.LittleEndian.Uint32(got[off : off+4])
		if got32 != want {
			t.Errorf("color[%d]: got 0x%08X want 0x%08X", i, got32, want)
		}
		off += 4
	}

	// 3 个 byte (face/hair/voice)
	if got[off] != 0 || got[off+1] != 0 || got[off+2] != 0 {
		t.Errorf("face/hair/voice not all zero: %v", got[off:off+3])
	}
	off += 3

	// scale = float32(1.0) = 0x3F800000
	scaleBits := binary.LittleEndian.Uint32(got[off : off+4])
	if scaleBits != 0x3F800000 {
		t.Errorf("scale bits: got 0x%08X want 0x3F800000 (=1.0)", scaleBits)
	}
	off += 4

	if off != len(got) {
		t.Errorf("trailing bytes: %d unread of total %d", len(got)-off, len(got))
	}
}

// ---------------------------------------------------------------------------
// TestEncodeCMUseSkill
// CM_USE_SKILL = int32 skill_id + int32 target_id + byte skill_lvl = 9 bytes.
// 验证 byte order 与 cm_use_skill.lua 读序一致。
// ---------------------------------------------------------------------------
func TestEncodeCMUseSkill(t *testing.T) {
	buf := make([]byte, 0, 9)
	buf = appendInt32(buf, 0x12345678) // skill_id
	buf = appendInt32(buf, 0x0BADF00D) // target_id (low 32-bit pattern)
	buf = append(buf, 0x07)            // skill_lvl

	if len(buf) != 9 {
		t.Fatalf("len = %d, want 9", len(buf))
	}
	if got := binary.LittleEndian.Uint32(buf[0:4]); got != 0x12345678 {
		t.Errorf("skill_id LE: got 0x%08X want 0x12345678", got)
	}
	if got := binary.LittleEndian.Uint32(buf[4:8]); got != 0x0BADF00D {
		t.Errorf("target_id LE: got 0x%08X want 0x0BADF00D", got)
	}
	if buf[8] != 0x07 {
		t.Errorf("skill_lvl: got 0x%02X want 0x07", buf[8])
	}
}

// ---------------------------------------------------------------------------
// TestParseSMLoot — 命题验证最关键的解析路径。
//
// 手工构造一个 SM_LOOT_ITEMLIST payload（mock server 端将来发的）：
//
//	corpse_eid=200001, item_id=100000001, count=1, item_uid=987654321
//	forge_id="F0RGE042"
//	stone_count=6, stones=[1001, 1002, 0, 1003, 0, 1004]
//	attr_count=2: ("phyAttack", 18), ("critRate", 7)
//
// 解析后必须：stones != nil、长度 6、forge_id == "F0RGE042"、attr 拿全。
// ---------------------------------------------------------------------------
func TestParseSMLoot(t *testing.T) {
	body := []byte{}
	body = appendInt32(body, 200001)    // corpse_eid
	body = appendInt32(body, 100000001) // item_id
	body = appendInt32(body, 1)         // item_count
	body = appendInt32(body, 987654321) // item_uid
	body = append(body, []byte("F0RGE042")...)
	body = appendInt32(body, 6) // stone_count
	for _, s := range []int32{1001, 1002, 0, 1003, 0, 1004} {
		body = appendInt32(body, s)
	}
	body = appendInt32(body, 2) // attr_count
	// attr1: utf16_null "phyAttack" + int32 18
	body = appendUTF16Null(body, "phyAttack")
	body = appendInt32(body, 18)
	// attr2: utf16_null "critRate" + int32 7
	body = appendUTF16Null(body, "critRate")
	body = appendInt32(body, 7)

	loot, err := parseLootItemlist(body)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if loot.Stones == nil {
		t.Fatal("loot.Stones is nil — 命题验证失败")
	}
	if len(loot.Stones) != 6 {
		t.Errorf("len(stones)=%d want 6", len(loot.Stones))
	}
	if loot.ForgeID != "F0RGE042" {
		t.Errorf("forge_id = %q want %q", loot.ForgeID, "F0RGE042")
	}
	if loot.ItemID != 100000001 {
		t.Errorf("item_id = %d want 100000001", loot.ItemID)
	}
	if loot.ItemUID != 987654321 {
		t.Errorf("item_uid = %d want 987654321", loot.ItemUID)
	}
	want := []int32{1001, 1002, 0, 1003, 0, 1004}
	for i, w := range want {
		if loot.Stones[i] != w {
			t.Errorf("stones[%d] = %d want %d", i, loot.Stones[i], w)
		}
	}
	if len(loot.Attrs) != 2 {
		t.Fatalf("len(attrs) = %d want 2", len(loot.Attrs))
	}
	if loot.Attrs[0].AttrID != "phyAttack" || loot.Attrs[0].Value != 18 {
		t.Errorf("attr[0] = %+v want {phyAttack 18}", loot.Attrs[0])
	}
	if loot.Attrs[1].AttrID != "critRate" || loot.Attrs[1].Value != 7 {
		t.Errorf("attr[1] = %+v want {critRate 7}", loot.Attrs[1])
	}
}

// TestParseSMLootMinimalNoAttrs — 早期 server wiring 可能只发 stones 不发 attrs。
// 不带 attr_count 段也要能解析，stones 仍然 != nil。
func TestParseSMLootMinimalNoAttrs(t *testing.T) {
	body := []byte{}
	body = appendInt32(body, 1)
	body = appendInt32(body, 100000002)
	body = appendInt32(body, 1)
	body = appendInt32(body, 12345)
	body = append(body, []byte("00000001")...)
	body = appendInt32(body, 6)
	for _, s := range []int32{0, 0, 0, 0, 0, 0} {
		body = appendInt32(body, s)
	}
	// 故意截断在 attr_count 之前。
	loot, err := parseLootItemlist(body)
	if err != nil {
		t.Fatalf("parse failed on no-attrs payload: %v", err)
	}
	if loot.Stones == nil || len(loot.Stones) != 6 {
		t.Errorf("stones absent on minimal payload")
	}
	if len(loot.Attrs) != 0 {
		t.Errorf("attrs unexpectedly present: %+v", loot.Attrs)
	}
}

// ---------------------------------------------------------------------------
// TestParseCharacterList — 0 角色 / 1 角色两种情形。
// 对齐 dispatcher.go sendCharacterList 实际格式（byte server_index +
// byte max_slots + byte count + N×entry）。
// ---------------------------------------------------------------------------
func TestParseCharacterList(t *testing.T) {
	t.Run("empty", func(t *testing.T) {
		body := []byte{0, 8, 0} // server_index=0, max_slots=8, count=0
		count, id, name := parseCharacterList(body)
		if count != 0 || id != 0 || name != "" {
			t.Errorf("empty case: got (%d, %d, %q)", count, id, name)
		}
	})
	t.Run("one_char", func(t *testing.T) {
		body := []byte{0, 8, 1}             // server_index, max_slots, count=1
		body = appendInt32(body, 100200300) // first char_id
		body = appendInt32(body, 133)       // account_id
		body = appendUTF16Null(body, "Hero")
		// 注意：完整 entry 还有 race/class/gender/level/world/... 但 parser
		// 只读到 name 就返回，余下字节不影响测试断言。
		count, id, name := parseCharacterList(body)
		if count != 1 || id != 100200300 || name != "Hero" {
			t.Errorf("got (%d, %d, %q) want (1, 100200300, Hero)", count, id, name)
		}
	})
}

// ---------------------------------------------------------------------------
// TestParseCreateCharResp — 成功 / 失败两个分支。
// ---------------------------------------------------------------------------
func TestParseCreateCharResp(t *testing.T) {
	t.Run("ok", func(t *testing.T) {
		body := []byte{0}
		body = appendInt32(body, 555)
		body = appendUTF16Null(body, "Sg42")
		result, charID, name := parseCreateCharResp(body)
		if result != 0 || charID != 555 || name != "Sg42" {
			t.Errorf("got (%d, %d, %q) want (0, 555, Sg42)", result, charID, name)
		}
	})
	t.Run("name_taken", func(t *testing.T) {
		body := []byte{2}
		body = appendInt32(body, 0)
		body = appendUTF16Null(body, "Sg42")
		result, charID, name := parseCreateCharResp(body)
		if result != 2 || charID != 0 || name != "Sg42" {
			t.Errorf("got (%d, %d, %q) want (2, 0, Sg42)", result, charID, name)
		}
	})
}

// ---------------------------------------------------------------------------
// 测试用本地 helper（不 export 出 main 包）
// ---------------------------------------------------------------------------

func appendUTF16Null(buf []byte, s string) []byte {
	for _, r := range s {
		var tmp [2]byte
		binary.LittleEndian.PutUint16(tmp[:], uint16(r))
		buf = append(buf, tmp[:]...)
	}
	return append(buf, 0, 0)
}
