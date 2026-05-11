package main

import "encoding/binary"

// slotToLuaOpcode58 把 5.8 中文客户端 CM_* slot 号映射到 4.8 opcode。
//
// 原因：scripts/handlers/cm_*.lua 用 register_handler(0xXX) 注册 4.8 opcode
// 作为 handler ID（Lua 业务层最初 fork 自 AL-Aion 4.8 命名空间）。NCSoft 每
// 个版本会重排 client-side handler array，但 server-side Lua 命名保留 4.8 不
// 动以避免 handler 文件大规模重命名。Gateway 因此承担"协议层 slot ↔ 业务层
// opcode"翻译职责。
//
// 已知项目：5/11 实测 + AionGermany 5.8 + BEY 4.8 ServerPacketsOpcodes 三方
// 印证。未列入此表的 slot 走 default 分支按原 slot 转 NATS（用于发现新包）。
var slotToLuaOpcode58 = map[int]uint16{
	gameSlot_CM_ENTER_WORLD:    0x15, // 5.8 0B  → 4.8 expects 4B char_id (gateway 注入)
	gameSlot_CM_CHARACTER_LIST: 0x11, // 5.8 4B  ↔ 4.8 opcode 0x11
	// CM_VERSION_CHECK / CM_TIME_CHECK / CM_MAC_ADDRESS / CM_L2AUTH_LOGIN_CHECK
	// / CM_CREATE_CHARACTER 在 gateway 内吃掉（auth + 字符创建 stub），不进 Lua。
	// IN_GAME 心跳 slot 92/107/159/231/234/492 暂不映射 — 等 Phase 3 发现真实业务。
}

// translateClientCM58 把 5.8 client wire-format 转成 Lua handler 可消费形态。
//
// 入参：5.8 slot 号 + 原始 payload + Session（用于读 SelectedCharID）。
// 出参：
//   - luaOp 是 Lua 注册的 4.8 opcode；
//   - newPayload 是经过 shape 修补的字节流（5.8 vs 4.8 wire 差异的包重建）；
//   - ok = true 表示已翻译可转 NATS；false 表示无映射（调用方按原 slot 处理）。
//
// shape 修补示例：5.8 CM_ENTER_WORLD 0B 没带 char_id → 用 Session 锁定的
// SelectedCharID 重建 4B LE 头部，使 Lua cm_enter_world.lua 仍能 read_int32()。
func translateClientCM58(slot int, payload []byte, sess *Session) (luaOp uint16, newPayload []byte, ok bool) {
	op, found := slotToLuaOpcode58[slot]
	if !found {
		return 0, payload, false
	}

	switch slot {
	case gameSlot_CM_ENTER_WORLD: // 5.8 0B → 注入 4B char_id LE 让 Lua handler 兼容。
		charID := sess.SelectedCharID()
		rewritten := make([]byte, 4+len(payload))
		binary.LittleEndian.PutUint32(rewritten[0:4], uint32(charID))
		copy(rewritten[4:], payload)
		return op, rewritten, true
	}

	return op, payload, true
}
