-- scripts/events/on_kill.lua
-- Entity death handler: SM_DIE broadcast, despawn/dead-flag, EXP award, level-up.
--
-- Entry point: on_entity_killed(killer_id, victim_id)
-- Called by CM_ATTACK, CM_USE_SKILL, and DoT death in on_tick.

local BROADCAST_RANGE = 200.0

-- --------------------------------------------------------
-- broadcast_die(dead_id): sends SM_DIE (0x44) to the dead entity (if player)
-- and all observers within BROADCAST_RANGE.
-- Must be called BEFORE world.despawn() — despawn removes the PositionComp.
-- --------------------------------------------------------
local function broadcast_die(dead_id)
    local buf = bytes.new()
    buf:write_int32(dead_id)
    local pkt = buf:to_string()

    local gw = entity.get_gateway_id(dead_id)
    if gw then player.send_packet(gw, 0x44, pkt) end

    local nearby = entity.get_nearby(dead_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local ngw = entity.get_gateway_id(nid)
        if ngw then player.send_packet(ngw, 0x44, pkt) end
    end
end

-- --------------------------------------------------------
-- on_entity_killed(killer_id, victim_id)
-- Central handler for all entity deaths in combat.
-- Broadcasts SM_DIE, updates entity state, awards EXP + level-up.
-- --------------------------------------------------------
function on_entity_killed(killer_id, victim_id)
    local victim_is_player = (entity.get_gateway_id(victim_id) ~= nil)

    -- 1. Broadcast SM_DIE before any state mutation (position must still exist).
    broadcast_die(victim_id)

    -- 2. Update victim state.
    if victim_is_player then
        entity.set_stat(victim_id, "dead", 1)
        entity.set_stat(victim_id, "hp", 0)
    else
        world.despawn(victim_id)  -- NPC: remove from ECS
    end

    log.info("killed: victim=" .. tostring(victim_id)
        .. (victim_is_player and " (player)" or " (NPC)"))

    -- 3. EXP award — only if killer is a player.
    local killer_gw = entity.get_gateway_id(killer_id)
    if not killer_gw then return end

    -- Phase S-11: PvP kill reward. Called only when the victim is a player;
    -- pvp.award_kill_points handles the cross-faction / same-faction gating
    -- internally and is a no-op for PvE kills.
    if victim_is_player and pvp then
        local ap_awarded = pvp.award_kill_points(killer_id, victim_id)
        if ap_awarded > 0 then
            log.info("PvP kill: killer=" .. tostring(killer_id)
                .. " victim=" .. tostring(victim_id)
                .. " ap=" .. tostring(ap_awarded))
        end
        -- PvP kills against players do NOT grant EXP (Abyss convention).
        -- Short-circuit here so the EXP-award block below is skipped.
        return
    end

    local victim_lvl = entity.get_stat(victim_id, "level")
    if victim_lvl <= 0 then victim_lvl = 1 end

    -- base_exp uses exp_table if loaded, else simple formula as fallback
    local base_exp   = exp_table and exp_table.kill_exp(victim_lvl)
                       or math.floor(victim_lvl * victim_lvl * 100)
    local exp_rate   = config.rates("exp", "normal")
    if exp_rate <= 0 then exp_rate = 1.0 end
    local total_exp  = math.floor(base_exp * exp_rate)

    -- Phase S-7: build the share list. Solo kill = killer only.
    -- Group kill = every member within 100 m of the victim (anti-leech gate).
    -- Each member gets: total_exp / share_count  (flat split, no level weighting yet).
    local SHARE_RANGE = 100.0
    local share_list = { killer_id }  -- always includes killer

    if group then
        local g = group.get(killer_id)
        if g then
            share_list = {}
            local nearby = entity.get_nearby(victim_id, SHARE_RANGE)
            local in_range = {}
            for _, nid in ipairs(nearby) do in_range[nid] = true end
            in_range[killer_id] = true  -- killer always counts, even if out of range

            for _, m in ipairs(g.members) do
                if in_range[m] or m == killer_id then
                    share_list[#share_list + 1] = m
                end
            end
        end
    end

    local per_share = math.max(1, math.floor(total_exp / #share_list))

    -- Award each member individually. Only the killer mutation path needs
    -- level-up effect broadcast; group members get their own SM_LEVEL_UP.
    for _, member_id in ipairs(share_list) do
        local gw = entity.get_gateway_id(member_id)
        if gw then
            local old_lvl = entity.get_stat(member_id, "level")
            local new_lvl = player.add_exp(gw, per_share)
            if new_lvl <= 0 then new_lvl = old_lvl end

            -- SM_EXP_UPDATE (0x19) — int64 exp_gained, int64 reserved=0.
            local exp_buf = bytes.new()
            exp_buf:write_int64(per_share)
            exp_buf:write_int64(0)
            player.send_packet(gw, 0x19, exp_buf:to_string())

            if new_lvl > old_lvl then
                entity.set_stat(member_id, "level", new_lvl)

                -- SM_LEVEL_UP (0x9D) — int32 entity_id, int32 new_level.
                local lv_buf = bytes.new()
                lv_buf:write_int32(member_id)
                lv_buf:write_int32(new_lvl)
                player.send_packet(gw, 0x9D, lv_buf:to_string())

                log.info("LEVEL UP: entity=" .. tostring(member_id)
                    .. " level=" .. tostring(new_lvl))
            end
        end
    end

    log.info("EXP awarded total=" .. tostring(total_exp)
        .. " per_share=" .. tostring(per_share)
        .. " shares=" .. tostring(#share_list)
        .. " killer=" .. tostring(killer_id))
end
