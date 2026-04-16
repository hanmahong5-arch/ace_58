-- scripts/lib/exp_table.lua
-- EXP formulas for kill rewards and level progression.
--
-- Values are approximations of the Aion 5.x progression curve.
-- Replace with exact values from DB (aion_GetCharInfo_20160818.exp column)
-- once the schema is fully mapped.

exp_table = {}

-- kill_exp(victim_level) -> base EXP awarded for killing an NPC of that level.
-- Formula: lv^2 * 100 gives a smooth curve (lv1=100, lv30=90000, lv65~4.2M).
exp_table.kill_exp = function(victim_level)
    local lv = math.max(1, math.min(65, math.floor(victim_level)))
    return math.floor(lv * lv * 100)
end

-- to_next(current_level) -> EXP required to advance from current_level to next.
-- Formula: 1000 * lv^2 * (1 + lv*0.1) is a rough match for Aion's exponential curve.
exp_table.to_next = function(current_level)
    local lv = math.max(1, math.min(64, math.floor(current_level)))
    return math.floor(1000 * lv * lv * (1 + lv * 0.1))
end
