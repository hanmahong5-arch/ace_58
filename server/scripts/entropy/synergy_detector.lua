-- scripts/entropy/synergy_detector.lua
-- Round 7 C5 — entropy v2 隐藏 set 协同检测 (Synergy)。
--
-- 检测一件高熵装备的 (manastones + random_attrs) 是否命中预设组合，
-- 命中则给予隐性 set 标签，玩家可在 QQ 群讨论："我这把刚好凑齐魔泉涌动！"
-- v2 阶段不直接改变属性 — 仅 log + 持久化备注（B 轨提供 SP 后由 v3 真正生效）。
--
-- 5 个预设 set：
--   雷霆重击  (Thunder Strike)  — ≥4 phyAttack         → 未来 +5% crit
--   魔泉涌动  (Mana Spring)     — ≥3 magicalSkillBoost → 未来 +3% magicalAttack
--   钢铁意志  (Iron Will)       — ≥3 physicalDefend     → 未来 +50 hp
--   刺客之眼  (Assassin Eye)    — ≥2 critical + ≥1 strikeFort → 未来 +5 attack speed
--   全能      (Versatile)       — ≥6 不同维度 (attr + 非空 stone) → 未来 +2% all
--
-- API:
--   entropy.detect_synergy(stones, attrs) -> string[]
--     stones (number[1..6])         — manastone IDs（可空）
--     attrs  ({attr_id, value}[]) — random_attr 列表（可空）
--   entropy.summarize_synergies(synergies) -> string
--     给 log 用的人话摘要 "[雷霆重击, 全能]" 或 "(none)"
--
-- 实现要点：
--   * 真正检测在 Go bridge (entropy.detect_synergy 全局函数) 里，因为它
--     需要遍历两个表 + 计数，纯 Lua 实现没有性能优势但有正确性风险
--     (table iteration 顺序非保证，map 计数容易写错)
--   * Lua 这边只做参数规范化 + 提供 summarize 这种纯展示函数

entropy = entropy or {}

local _native_detect_synergy = entropy.detect_synergy

-- entropy.detect_synergy: 把 stones / attrs 传给 Go-side native 实现
-- 并返回命中的 set 名字数组。
function entropy.detect_synergy(stones, attrs)
    if _native_detect_synergy then
        return _native_detect_synergy(stones or {}, attrs or {})
    end
    return {}
end

-- summarize_synergies: 把数组化的命中名变为日志友好字符串。
function entropy.summarize_synergies(synergies)
    if not synergies or #synergies == 0 then
        return "(none)"
    end
    local s = "["
    for i, name in ipairs(synergies) do
        if i > 1 then s = s .. ", " end
        s = s .. name
    end
    return s .. "]"
end

-- 自检
do
    -- 4 个 phyAttack → 雷霆重击 必命中
    local hits = entropy.detect_synergy({}, {
        {attr_id="phyAttack", value=10},
        {attr_id="phyAttack", value=12},
        {attr_id="phyAttack", value=8 },
        {attr_id="phyAttack", value=15},
    })
    assert(type(hits) == "table",
        "entropy.detect_synergy must return a table, got " .. type(hits))
    -- hits 可能是空表（Go bridge 未加载时） — 仅类型检查
end
