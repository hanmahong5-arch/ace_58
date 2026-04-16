-- scripts/skills/skill_1001.lua
-- Skill: Fierce Strike (physical melee burst)
-- Deals 1.5× normal physical damage to a single target.
-- Available as a universal placeholder combat skill for Phase S-5 testing.

skill.register({
    id       = 1001,
    name     = "Fierce Strike",
    cooldown = 8,    -- 8-second cooldown
    mp_cost  = 30,
    range    = 6.0,  -- metres (standard melee range)

    on_use = function(ctx, target_id)
        if not target_id or target_id == 0 then return end

        -- Validate target is within skill range.
        local nearby = entity.get_nearby(ctx.entity_id, 6.0)
        local in_range = false
        for _, nid in ipairs(nearby) do
            if nid == target_id then in_range = true; break end
        end
        if not in_range then return end

        -- Hit check: base 90 % ± 2 % per level diff, clamped [10 %, 95 %].
        local atk_lvl = math.max(1, entity.get_stat(ctx.entity_id, "level"))
        local def_lvl = math.max(1, entity.get_stat(target_id, "level"))
        local hit_chance = math.min(0.95, math.max(0.10,
            0.90 + (atk_lvl - def_lvl) * 0.02))
        if math.random() > hit_chance then return end  -- miss (MP and cooldown consumed)

        -- 1.5× physical damage with crit.
        local base_dmg  = math.floor((10 + atk_lvl * 5) * 1.5)
        local lv_factor = math.max(0.5, math.min(1.5,
            1.0 + (def_lvl - atk_lvl) * 0.05))
        local damage    = math.floor(base_dmg * lv_factor)
        local is_crit   = math.random() < 0.10
        if is_crit then damage = math.floor(damage * 2.0) end

        local remaining = combat.deal_damage(ctx.entity_id, target_id, damage, "physical")

        -- SM_SKILL_RESULT (0x5E): broadcast to nearby observers.
        -- Format (LE, unverified):
        --   int32 caster_id, int32 skill_id, int32 target_id,
        --   int32 damage, int32 remaining_hp, byte crit_flag
        local buf = bytes.new()
        buf:write_int32(ctx.entity_id)
        buf:write_int32(1001)
        buf:write_int32(target_id)
        buf:write_int32(damage)
        buf:write_int32(math.floor(remaining))
        buf:write_byte(is_crit and 1 or 0)
        local pkt = buf:to_string()

        local obs = entity.get_nearby(ctx.entity_id, 200.0)
        for _, nid in ipairs(obs) do
            local gw = entity.get_gateway_id(nid)
            if gw then player.send_packet(gw, 0x5E, pkt) end
        end

        log.info("skill_1001: entity=" .. tostring(ctx.entity_id)
            .. " target=" .. tostring(target_id)
            .. " dmg=" .. tostring(damage)
            .. (is_crit and " CRIT" or ""))

        -- Death handling.
        if remaining <= 0 then
            if on_entity_killed then
                on_entity_killed(ctx.entity_id, target_id)
            else
                -- Fallback if on_kill.lua is not loaded.
                local gw2 = entity.get_gateway_id(target_id)
                if not gw2 then world.despawn(target_id)
                else entity.set_stat(target_id, "dead", 1) end
            end
        end
    end,
})
