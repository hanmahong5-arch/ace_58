-- scripts/lib/class_names.lua
-- Round 11 A8 — class id ↔ class name 集中映射表（patch 07 前置）。
--
-- entity.set_stat 仅支持 float64 数值 (bridge.go:592-598), 故 ECS 内
-- 持久化的是 class_id (0..14 数字)。entropy v1 random_attr_helper / 未来
-- loot.lua / quest reward 等需要 class_name 字符串做 bias lookup 的路径
-- 统一查本表，避免每个 caller 各自维护映射 (DRY 失败)。
--
-- ID 编码必须与 random_attr_helper.lua §2 bias_matrix 的 12 + 2 entry
-- 完全对齐。NCSoft SP `aion_GetCharInfo_20160818` 返回的 class 字段是
-- 0-based 0..14（5.8 末期 14 职业），未知 id 走 "default" 触发 baseline
-- 权重而非 fallback 到 Gladiator (避免误导 class bias 测试)。

class_names = class_names or {}

-- ============================================================
-- §1 — id → name 映射 (5.8 末期 14 职业)
-- ============================================================
--   战士: 0 Gladiator / 1 Templar
--   侦察: 2 Assassin / 3 Ranger
--   法师: 4 Sorcerer / 5 Spiritmaster
--   治疗: 6 Cleric / 7 Chanter
--   工程: 8 Aethertech / 9 Gunslinger
--   巫师: 10 Songweaver / 11 Bard
--   12-13 reserved (custom job slots, Q3 自创职业 spec 落地后启用)

class_names.id_to_name = {
    [0]  = "Gladiator",
    [1]  = "Templar",
    [2]  = "Assassin",
    [3]  = "Ranger",
    [4]  = "Sorcerer",
    [5]  = "Spiritmaster",
    [6]  = "Cleric",
    [7]  = "Chanter",
    [8]  = "Aethertech",
    [9]  = "Gunslinger",
    [10] = "Songweaver",
    [11] = "Bard",
}

-- ============================================================
-- §2 — Lookup helpers
-- ============================================================

-- class_names.of(class_id) -> string
-- 容错: 输入 nil / 非数 / 越界一律返回 "default"。entropy.bias_matrix.default
-- 是空表 → 所有 attr 走 BIAS_BASELINE=1.0, 行为是"无 class 偏置"。
function class_names.of(class_id)
    local id = tonumber(class_id)
    if not id then return "default" end
    return class_names.id_to_name[id] or "default"
end

-- class_names.of_entity(entity_id) -> string
-- 便利包装: 直接吃 ECS entity_id, 内部读 "class_id" stat。
-- 用于 patch 02 instance.on_boss_kill / patch 06 loot.roll_and_grant 等
-- 已知 entity_id 想拿 class_name 的场景。
function class_names.of_entity(entity_id)
    if not entity or not entity.get_stat then return "default" end
    local cid = entity.get_stat(entity_id, "class_id")
    return class_names.of(cid)
end

-- ============================================================
-- §3 — 自检
-- ============================================================
do
    assert(class_names.of(0) == "Gladiator", "class 0 should map to Gladiator")
    assert(class_names.of(11) == "Bard",     "class 11 should map to Bard")
    assert(class_names.of(99) == "default",  "out-of-range should fall to default")
    assert(class_names.of(nil) == "default", "nil input should fall to default")
    assert(class_names.of("x") == "default", "non-numeric should fall to default")
end
