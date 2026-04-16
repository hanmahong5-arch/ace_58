-- scripts/events/on_tick.lua
-- Game-loop hook: invoked every tick at worldCfg.Server.TickRate (default 20/sec).
--
-- Phase S-5 responsibilities (extends S-4):
--   1. Expose current_tick as a global for skill cooldown tracking.
--   2. HP/MP/FP passive regeneration + SM_STAT_INFO (0x1E) delivery.
--   3. Buff/DoT tick processing: purge expired buffs, apply DoT damage.
--   4. NPC patrol AI step (every tick).

-- Global: written every tick so skill cooldown checks have a reference.
current_tick = 0

-- Regen fires once per REGEN_INTERVAL ticks.  At 20 tps this is 1 second.
local REGEN_INTERVAL = 20

-- Percentage of max stat restored per regen interval (out of combat).
local HP_REGEN_PCT = 0.01  -- 1 % of max_hp per second
local MP_REGEN_PCT = 0.02  -- 2 % of max_mp per second
local FP_REGEN_PCT = 0.01  -- 1 % of max_fp per second

-- Broadcast range for DoT-kill SM_DIE.
local BROADCAST_RANGE = 200.0

-- --------------------------------------------------------
-- send_stat_info(eid, gw): builds and sends SM_STAT_INFO (0x1E).
-- Packet format (LE, unverified — adjust after packet capture):
--   int32 entity_id, int32 hp, int32 max_hp,
--   int32 mp, int32 max_mp, int32 fp, int32 max_fp
-- --------------------------------------------------------
local function send_stat_info(eid, gw)
    local buf = bytes.new()
    buf:write_int32(eid)
    buf:write_int32(math.floor(entity.get_stat(eid, "hp")))
    buf:write_int32(math.floor(entity.get_stat(eid, "max_hp")))
    buf:write_int32(math.floor(entity.get_stat(eid, "mp")))
    buf:write_int32(math.floor(entity.get_stat(eid, "max_mp")))
    buf:write_int32(math.floor(entity.get_stat(eid, "fp")))
    buf:write_int32(math.floor(entity.get_stat(eid, "max_fp")))
    player.send_packet(gw, 0x1E, buf:to_string())
end

-- --------------------------------------------------------
-- regen_player(eid, gw): restores HP/MP/FP by fixed percentages.
-- Skips dead entities and entities with max stat = 0 (not yet initialised).
-- Phase S-9: FP regen is suppressed while airborne (flight drain owns FP).
-- Sends SM_STAT_INFO when any stat changes.
-- --------------------------------------------------------
local function regen_player(eid, gw)
    if entity.get_stat(eid, "dead") > 0 then return end

    local hp,  max_hp = entity.get_stat(eid, "hp"),  entity.get_stat(eid, "max_hp")
    local mp,  max_mp = entity.get_stat(eid, "mp"),  entity.get_stat(eid, "max_mp")
    local fp,  max_fp = entity.get_stat(eid, "fp"),  entity.get_stat(eid, "max_fp")

    local airborne = flight and flight.is_airborne(eid)

    local changed = false
    if max_hp > 0 and hp < max_hp then
        entity.set_stat(eid, "hp", math.min(hp + max_hp * HP_REGEN_PCT, max_hp))
        changed = true
    end
    if max_mp > 0 and mp < max_mp then
        entity.set_stat(eid, "mp", math.min(mp + max_mp * MP_REGEN_PCT, max_mp))
        changed = true
    end
    if not airborne and max_fp > 0 and fp < max_fp then
        entity.set_stat(eid, "fp", math.min(fp + max_fp * FP_REGEN_PCT, max_fp))
        changed = true
    end

    if changed then
        send_stat_info(eid, gw)
    end
end

-- --------------------------------------------------------
-- handle_dot_death(eid): broadcast SM_DIE and mark player dead (or despawn NPC).
-- Called when a DoT reduces HP to 0.
-- --------------------------------------------------------
local function handle_dot_death(eid)
    entity.set_stat(eid, "hp", 0)
    local buf = bytes.new()
    buf:write_int32(eid)
    local pkt = buf:to_string()

    -- Send to the dying entity and all nearby
    local gw = entity.get_gateway_id(eid)
    if gw then player.send_packet(gw, 0x44, pkt) end
    local nearby = entity.get_nearby(eid, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local ngw = entity.get_gateway_id(nid)
        if ngw then player.send_packet(ngw, 0x44, pkt) end
    end

    if gw then
        entity.set_stat(eid, "dead", 1)  -- player: keep entity, await revive
    else
        world.despawn(eid)               -- NPC: remove from world
    end
    log.info("on_tick: DoT killed entity=" .. tostring(eid))
end

-- --------------------------------------------------------
-- process_buffs(eid, tick): runs DoT damage and purges expired entries.
-- --------------------------------------------------------
local function process_buffs(eid, tick)
    -- Remove expired buffs first.
    combat.purge_expired(eid, tick)

    -- Apply damage for each active DoT.
    local buffs = combat.get_buffs(eid)
    for _, b in ipairs(buffs) do
        if b.is_dot and b.dmg_per_tick > 0 then
            local remaining = combat.deal_damage(0, eid, b.dmg_per_tick, b.element)
            local gw = entity.get_gateway_id(eid)
            if gw then
                send_stat_info(eid, gw)
            end
            if remaining <= 0 then
                handle_dot_death(eid)
                return  -- entity dead; skip remaining buffs
            end
        end
    end
end

-- --------------------------------------------------------
-- on_tick(tick): called by Go Dispatcher every game tick.
-- --------------------------------------------------------
function on_tick(tick)
    current_tick = tick
    local players = entity.get_all_players()

    for _, eid in ipairs(players) do
        local gw = entity.get_gateway_id(eid)

        -- Phase S-9: Flight FP drain runs every tick (not throttled).
        -- If the player is airborne we drain first; on force-land the
        -- regen branch below will run on the next interval as normal.
        if flight and flight.is_airborne(eid) then
            local still_airborne = flight.drain(eid)
            if still_airborne and gw and tick % REGEN_INTERVAL == 0 then
                -- Airborne: only HP/MP regen, no FP regen. Emit SM_STAT_INFO
                -- once per interval so the client UI stays in sync with FP drain.
                send_stat_info(eid, gw)
            end
        end

        -- Regen pass (throttled to once per second)
        if tick % REGEN_INTERVAL == 0 and gw then
            regen_player(eid, gw)
        end

        -- Buff/DoT tick every game tick
        process_buffs(eid, tick)
    end

    -- NPC patrol AI (each NPC gates itself internally by tick offset)
    if patrol then
        local npcs = entity.get_all_npcs()
        for _, nid in ipairs(npcs) do
            patrol.step(nid, tick)
        end
    end
end
