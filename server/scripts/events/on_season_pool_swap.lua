-- scripts/events/on_season_pool_swap.lua
-- STORY-21: invoked by the asynq worker KindSeasonPoolSwap on the recurring
-- weekly cron ("0 6 * * 1" = every Monday 06:00) to rotate the global
-- entropy season_pool. The 5 themed pools are defined in
-- scripts/entropy/season_pool.lua; this handler stores the active seed in a
-- shared global so subsequent item / loot / mail / instance code paths read
-- the cron-driven value rather than recomputing from os.time() each call.
--
-- 战略命题: "玩家不能 5 次副本就把一切算清楚"。每周切池让全服在同一时刻
-- 看到同一个主题（"本周混沌之潮"），是高熵 v3 的核心 — 见
-- doc/business/guanghui-yongheng-roadmap-20260425.md §Q2 涌现机制。
--
-- Contract:
--   on_season_pool_swap(season_seed:integer)
--
-- Validation:
--   * season_seed 必须是 number 且落在 [0, 2^32) 区间内（uint32 语义，
--     与 forge_id seed 段对齐；Round 8 C6 的 stream_id=200 sub-PRNG
--     依赖此约束保持决定性）。
--   * 非法值 → log.error + 提前 return false，不更新 entropy.season_seed_active。
--     选择"丢弃非法 tick"而非"clamp 后继续"是因为 cron payload 是 Go 编码的
--     int64，越界几乎只可能来自 schema bug；静默修复会掩盖故障。
--
-- 注意:
--   * 此 handler 不做 SP 调用 — 池切换是纯 Lua 内存状态变更，全服一致性
--     由 cron 到达的同时性保证（asynq 单 leader 调度）。
--   * 之前未生效的 season_seed 透过 entropy.season_seed() (add_item_helper.lua)
--     仍可工作 (degraded fallback to os.time()-based ISO 周)；此 handler 写入的
--     entropy.season_seed_active 让需要"显式当前 cron tick"的逻辑读到准确值。

-- uint32 上限（2^32），用作 season_seed 合法范围上界（exclusive）。
local SEASON_SEED_MAX = 4294967296

function on_season_pool_swap(season_seed)
    -- 类型校验：cron payload 走 JSON int64，非 number 一定是上游 bug。
    if type(season_seed) ~= "number" then
        log.error("on_season_pool_swap: invalid season_seed type="
            .. type(season_seed) .. " (expected number)")
        return false
    end

    -- 范围校验：[0, 2^32)。负数 / 越界都拒收。
    if season_seed < 0 or season_seed >= SEASON_SEED_MAX then
        log.error("on_season_pool_swap: season_seed out of range value="
            .. tostring(season_seed)
            .. " (expected [0, " .. tostring(SEASON_SEED_MAX) .. "))")
        return false
    end

    -- 整数化（防止 cron 上游传 1234.5 这种 float）。
    season_seed = math.floor(season_seed)

    -- 解析当前激活池名，校验 entropy lib 已加载（hot-reload 顺序保险）。
    if not entropy or not entropy.season_pool or not entropy.season_pool.active_name then
        log.error("on_season_pool_swap: entropy.season_pool lib not loaded — "
            .. "check scripts/entropy/season_pool.lua load order")
        return false
    end

    -- 写入 cron 驱动的全局当前 seed。下游想"显式读 cron tick"的逻辑可读
    -- entropy.season_seed_active；想"周自动滚动"的旧逻辑继续读
    -- entropy.season_seed() 函数（不变）。
    entropy.season_seed_active = season_seed

    local pool_name = entropy.season_pool.active_name(season_seed)
    log.info("entropy: season_pool swap -> seed="
        .. tostring(season_seed) .. " pool=" .. tostring(pool_name))
    return true
end
