-- scripts/handlers/cm_attack.lua
-- CM_ATTACK (0x2C): client requests a melee attack on a target entity.
--
-- Payload (binary, little-endian):
--   int32  target_entity_id  — ECS entity ID of the attack target
--   byte   attack_type       — 0=normal, 1=power (reserved, unused in S-4)
--
-- Server action:
--   1. Validate the target is within ATTACK_RANGE.
--   2. Roll hit chance via damage_calc.check_hit.
--   3. Apply physical damage (damage_calc.physical).
--   4. Broadcast SM_ATTACK (0x8E) to nearby players.
--   5. On death: broadcast SM_DIE (0x44) and remove entity from ECS.
--
-- SM_ATTACK payload (LE):
--   int32  attacker_entity_id
--   int32  target_entity_id
--   int32  damage              — 0 on miss
--   int32  target_remaining_hp
--   byte   hit_result          — 0=miss, 1=hit, 2=crit
--
-- SM_DIE payload (LE):
--   int32  dead_entity_id
--
-- NOTE: SM_ATTACK / SM_DIE wire formats are unverified; adjust after packet capture.

local ATTACK_RANGE    = 6.0    -- metres; typical AION melee range
local BROADCAST_RANGE = 200.0  -- metres; who sees the attack

-- --------------------------------------------------------
-- broadcast_attack: sends SM_ATTACK to all nearby observers.
-- --------------------------------------------------------
local function broadcast_attack(attacker_id, target_id, damage, remaining_hp, is_crit)
    local hit_result = 0
    if damage > 0 then
        hit_result = is_crit and 2 or 1
    end

    local buf = bytes.new()
    buf:write_int32(attacker_id)
    buf:write_int32(target_id)
    buf:write_int32(damage)
    buf:write_int32(math.floor(remaining_hp))
    buf:write_byte(hit_result)
    local pkt = buf:to_string()

    local nearby = entity.get_nearby(attacker_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local gw = entity.get_gateway_id(nid)
        if gw then
            player.send_packet(gw, 0x8E, pkt)
        end
    end
end

-- --------------------------------------------------------
-- handle_death: delegates to on_entity_killed (events/on_kill.lua).
-- Broadcasts SM_DIE, handles EXP award and respawn state.
-- Falls back to basic despawn/dead-flag if on_kill.lua is not loaded.
-- --------------------------------------------------------
local function handle_death(attacker_id, dead_id)
    if on_entity_killed then
        on_entity_killed(attacker_id, dead_id)
    else
        -- Minimal fallback (on_kill.lua not yet loaded during startup).
        local buf = bytes.new()
        buf:write_int32(dead_id)
        local pkt = buf:to_string()
        local nearby = entity.get_nearby(dead_id, BROADCAST_RANGE)
        for _, nid in ipairs(nearby) do
            local gw = entity.get_gateway_id(nid)
            if gw then player.send_packet(gw, 0x44, pkt) end
        end
        if not entity.get_gateway_id(dead_id) then
            world.despawn(dead_id)
        else
            entity.set_stat(dead_id, "dead", 1)
        end
    end
end

-- --------------------------------------------------------
-- Handler
-- --------------------------------------------------------
register_handler(0x2C, function(ctx, payload)
    local target_id  = payload:read_int32()
    local _atk_type  = payload:read_byte()  -- reserved, unused

    -- Validate target is within melee range.
    local nearby = entity.get_nearby(ctx.entity_id, ATTACK_RANGE)
    local in_range = false
    for _, nid in ipairs(nearby) do
        if nid == target_id then
            in_range = true
            break
        end
    end
    if not in_range then
        log.warn("CM_ATTACK: target out of range"
            .. " attacker=" .. tostring(ctx.entity_id)
            .. " target="   .. tostring(target_id))
        return
    end

    -- Phase S-11: PvP gate — blocks self-target, safe zone, and unflagged
    -- same-faction friendly fire. PvE (attacker or target is an NPC) passes
    -- through unconditionally.
    if pvp then
        local ok, reason = pvp.can_damage(ctx.entity_id, target_id)
        if not ok then
            log.info("CM_ATTACK: pvp blocked"
                .. " attacker=" .. tostring(ctx.entity_id)
                .. " target="   .. tostring(target_id)
                .. " reason="   .. tostring(reason))
            return
        end
    end

    -- Hit check.
    if not damage_calc.check_hit(ctx.entity_id, target_id) then
        -- Miss: broadcast 0-damage attack.
        broadcast_attack(ctx.entity_id, target_id, 0, entity.get_stat(target_id, "hp"), false)
        return
    end

    -- Apply damage; returns amount dealt, remaining HP, and crit flag.
    local damage, remaining_hp, is_crit = damage_calc.physical(ctx.entity_id, target_id)

    log.info("CM_ATTACK hit"
        .. " attacker=" .. tostring(ctx.entity_id)
        .. " target="   .. tostring(target_id)
        .. " dmg="      .. tostring(damage)
        .. " hp_left="  .. tostring(remaining_hp)
        .. (is_crit and " CRIT" or ""))

    broadcast_attack(ctx.entity_id, target_id, damage, remaining_hp, is_crit)

    -- Check death.
    if remaining_hp <= 0 then
        handle_death(ctx.entity_id, target_id)
    end
end)
