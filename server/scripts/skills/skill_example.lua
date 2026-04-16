-- scripts/skills/skill_example.lua
-- Example: Flame Spray (Sorcerer AoE fire skill)
-- Demonstrates how to write a skill script.
-- Each skill is one file. Hot-reloadable. Zero compilation.

local skill = {}

skill.id = 1001
skill.name = "Flame Spray"
skill.cooldown = 8          -- seconds
skill.cast_time = 1.5       -- seconds
skill.mp_cost = 120
skill.range = 20            -- meters
skill.aoe_radius = 10       -- meters

skill.on_cast = function(caster, targets, skill_level)
    -- Scaling formula: base + level * growth
    local base_damage = 200 + skill_level * 45
    local dot_damage = 50 + skill_level * 12
    local dot_duration = 6  -- seconds

    -- Apply rate multiplier from config (hot-reloadable)
    local rate = config.rates("drop", "normal") -- example

    for _, target in ipairs(targets) do
        -- Check hit (accuracy vs evasion)
        if combat.check_hit(caster, target) then
            -- Direct damage
            combat.deal_damage(caster, target, base_damage, "magical_fire")

            -- DoT effect
            combat.apply_dot(target, dot_damage, dot_duration, "fire_burn")

            -- Log for analytics
            log.info("skill_hit", {
                caster = caster, target = target,
                skill = skill.id, damage = base_damage,
            })
        end
    end

    -- Persist skill usage to database (async, non-blocking)
    db.call_async("ap_update_skill_usage", caster, skill.id)
end

return skill
