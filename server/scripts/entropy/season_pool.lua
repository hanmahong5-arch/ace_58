-- scripts/entropy/season_pool.lua
-- Round 8 C6 — entropy v3 季节性 modifier 池切换。
--
-- 战略命题: "玩家不能 5 次副本就把一切算清楚"。v0/v1/v2 提供了
-- per-item 高熵；v3 提供 per-week 全服高熵 — 同一周所有玩家面对
-- 同一个"主题池"（modifier flavor），这是"涌现事件"的实现基石。
--
-- 设计要点:
--   1. **全服一致性**: 同一周 season_seed 相同 → 全服激活同一个池。
--      这是涌现事件的核心 — 玩家可以在 QQ 群讨论"本周是混沌之潮"。
--   2. **决定性**: active_pool(seed) 是纯函数；同 seed 永远同 pool。
--      切换公式: pool_list[(seed % #pool_list) + 1]，可预告。
--   3. **乘子语义**: 池修饰 v0 manastone 槽数 + v1 random_attr 偏置矩阵；
--      不直接改 attr 值范围（保留 v1 实证 min/max 边界，避免溢出）。
--   4. **Stream 隔离**: stream_id=200 预留给 season pool 派生子 PRNG，
--      若 Cycle 17 给某些池加 per-player 子骰子（如 lucky_seven 暴击随机
--      额外掉 epic stone）则用此流，避免与 v0/v1 统计相关。
--   5. **降级**: 未知池名走 identity（return base_value），保证
--      v0/v1 在 v3 失败时仍可独立工作。
--
-- API:
--   entropy.season_pool.active_pool(season_seed) -> table { name, attr_bias, stone_delta, ... }
--   entropy.season_pool.apply_to_attr(base_value, attr_id, pool) -> number
--   entropy.season_pool.apply_to_stones(stone_count, pool) -> number
--
-- 参考: doc/business/guanghui-yongheng-roadmap-20260425.md §Q2 涌现机制；
--       references/entropy-mechanisms.md "v3 候选优先级 #1"

entropy = entropy or {}
entropy.season_pool = entropy.season_pool or {}

-- ============================================================
-- §1 — 5 个主题池定义
-- ============================================================
--
-- 每个池字段:
--   name        (string) — 池标识，全服可见
--   display     (string) — QQ 群文本里给玩家看的中文名
--   attr_bias   (table)  — {[attr_id] = multiplier}，作用于 v1 抽到该 attr
--                          后的 value（绝对值乘子，保留正负号）
--   stone_delta (number) — manastone 槽数偏移 (+1 / -1 / 0)
--   note        (string) — 设计意图（dev 注释，玩家不可见）
--
-- 阈值取舍:
--   * stone_delta ∈ {-1, 0, +1}：超过 ±1 会让 rare/epic 装备槽数失控
--     （rare=7 槽 + 2 = 9，逼近 epic=10，破坏 tier 区分）
--   * attr_bias ∈ [0.85, 1.20]：>1.2 在 1000 抽样下平均值偏移 >20pp
--     变成"必抽强 attr"压抑多样性；<0.85 玩家会觉得"周运气太差"
--   * synergy_threshold_delta 留口子但本 cycle 不实现（synergy_detector.lua
--     的阈值是 hardcode 的；改它需要 v2-B 重构，留 Cycle 17）

entropy.season_pool.pools = {
    {
        name = "tide_chaos",
        display = "混沌之潮",
        attr_bias = {
            magicalSkillBoost = 1.15,  -- +15% 魔法穿透
            phyAttack         = 0.90,  -- -10% 物攻
            magicalAttack     = 1.10,
        },
        stone_delta = 0,
        note = "魔法系周；偏向 Sorcerer/Spiritmaster/Cleric/Bard",
    },
    {
        name = "iron_dawn",
        display = "钢铁黎明",
        attr_bias = {
            physicalDefend    = 1.15,
            magicalAttack     = 0.95,
            magicalSkillBoost = 0.90,
            maxHp             = 1.10,
        },
        stone_delta = 0,
        note = "防御周；坦克友好，Templar/Aethertech 高光",
    },
    {
        name = "crit_storm",
        display = "暴击风暴",
        attr_bias = {
            critical        = 1.20,
            magicalCritical = 1.20,
            phyAttack       = 1.05,
        },
        stone_delta = 0,
        note = "极化周；高方差 — Assassin/Ranger 周",
    },
    {
        name = "lucky_seven",
        display = "幸运周",
        attr_bias = {
            -- 全 attr 普乘 1.05 — 最温和最受欢迎的池
            phyAttack         = 1.05,
            magicalAttack     = 1.05,
            magicalSkillBoost = 1.05,
            physicalDefend    = 1.05,
            critical          = 1.05,
        },
        stone_delta = 1,  -- +1 manastone 槽 (rare 8 / epic 7)
        note = "送福利周；玩家最爱，每月期待",
    },
    {
        name = "void_drift",
        display = "虚空漂移",
        attr_bias = {
            -- 攻防全压制 0.90，但 utility / resist 抬高
            phyAttack         = 0.90,
            magicalAttack     = 0.90,
            physicalDefend    = 0.90,
            speed             = 1.20,
            arParalyze        = 1.15,
            arSilence         = 1.15,
        },
        stone_delta = -1,  -- -1 manastone 槽 (常见 5 / rare 6)
        note = "硬核周；逼玩家依赖技能而非装备",
    },
}

-- ============================================================
-- §2 — Pool 选择 (决定性)
-- ============================================================

-- entropy.season_pool.active_pool(season_seed) -> pool table
-- 同 seed → 同 pool；切换发生在 season_seed 改变（每周 604800 秒一次）。
function entropy.season_pool.active_pool(season_seed)
    season_seed = tonumber(season_seed) or 0
    local pools = entropy.season_pool.pools
    local n = #pools
    if n == 0 then return nil end
    -- season_seed 可能是 0 或负数 (历史 epoch)；mod 后 +1 落入 [1, n]
    local idx = (season_seed % n) + 1
    return pools[idx]
end

-- entropy.season_pool.active_name(season_seed) -> string
-- 便利函数：返回当前池显示名（供 M3 QQ 群机器人查询）
function entropy.season_pool.active_name(season_seed)
    local p = entropy.season_pool.active_pool(season_seed)
    return p and p.display or "(unknown)"
end

-- ============================================================
-- §3 — 修饰函数
-- ============================================================

-- entropy.season_pool.apply_to_attr(base_value, attr_id, pool) -> number
-- v1 random_attr_helper.lua 在抽到 attr_id+value 后调本函数加 pool 乘子。
-- pool 为 nil 或无对应 attr 偏置 → identity (return base_value)。
-- 保留正负号：负 attr (debuff) 也按倍数缩放，符合"主题压制"语义。
function entropy.season_pool.apply_to_attr(base_value, attr_id, pool)
    base_value = tonumber(base_value) or 0
    if not pool or not pool.attr_bias then return base_value end
    local mul = pool.attr_bias[attr_id]
    if not mul then return base_value end  -- 池不影响该 attr，原样返回
    -- math.floor(x + 0.5) = round-half-up；负数也对 (floor(-1.5+0.5)=-1)。
    -- 用 round 而不是 floor 避免单向偏移（floor 会让乘子永远略偏小）。
    local v = base_value * mul
    if v >= 0 then
        return math.floor(v + 0.5)
    else
        return -math.floor(-v + 0.5)
    end
end

-- entropy.season_pool.apply_to_stones(stone_count, pool) -> number
-- v0 add_item_helper.lua 在 roll_manastones 之前可调本函数调整槽数。
-- 边界 clamp 到 [0, 6]：6 是 manastone slot 物理上限（user_item_option 表 6 列）。
function entropy.season_pool.apply_to_stones(stone_count, pool)
    stone_count = tonumber(stone_count) or 0
    if not pool then return stone_count end
    local delta = tonumber(pool.stone_delta) or 0
    local result = stone_count + delta
    if result < 0 then result = 0 end
    if result > 6 then result = 6 end
    return result
end

-- ============================================================
-- §4 — 自检 (load 时跑一次)
-- ============================================================
do
    -- 决定性自检
    local p1 = entropy.season_pool.active_pool(0)
    local p2 = entropy.season_pool.active_pool(0)
    assert(p1 and p2 and p1.name == p2.name,
        "season_pool.active_pool must be deterministic")

    -- 多样性自检：5 个不同 seed 至少 2 个不同 pool
    local names = {}
    for s = 0, 4 do
        local p = entropy.season_pool.active_pool(s)
        names[p.name] = (names[p.name] or 0) + 1
    end
    local unique = 0
    for _ in pairs(names) do unique = unique + 1 end
    assert(unique >= 2,
        "season_pool: 5 seeds should yield >= 2 distinct pools, got " .. unique)

    -- apply_to_attr 自检
    local fake_pool = { attr_bias = { phyAttack = 1.5 } }
    assert(entropy.season_pool.apply_to_attr(10, "phyAttack", fake_pool) == 15,
        "apply_to_attr basic multiplier failed")
    assert(entropy.season_pool.apply_to_attr(10, "unknown_attr", fake_pool) == 10,
        "apply_to_attr fallback (unknown attr) failed")
    assert(entropy.season_pool.apply_to_attr(10, "phyAttack", nil) == 10,
        "apply_to_attr fallback (nil pool) failed")

    -- apply_to_stones 自检 + clamp
    assert(entropy.season_pool.apply_to_stones(5, { stone_delta = 1 }) == 6,
        "apply_to_stones +1 failed")
    assert(entropy.season_pool.apply_to_stones(6, { stone_delta = 1 }) == 6,
        "apply_to_stones upper clamp failed")
    assert(entropy.season_pool.apply_to_stones(0, { stone_delta = -1 }) == 0,
        "apply_to_stones lower clamp failed")
end
