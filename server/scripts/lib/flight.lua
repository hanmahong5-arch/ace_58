-- scripts/lib/flight.lua
-- Flight state machine and Flight-Points (FP) drain logic.
--
-- AION flight has three states stored in ECS stat "flight_state":
--   0 = GROUND  — walking, standing (FP regenerates)
--   1 = GLIDE   — momentum glide, slow FP drain, no altitude gain
--   2 = FLY     — powered flight, fast FP drain, free altitude
--
-- FP is consumed each tick while airborne. At 0 FP the server force-lands
-- the player and broadcasts SM_FLY_STATE = GROUND.
--
-- SM_FLY_STATE (0x74) payload (LE, unverified):
--   int32  entity_id
--   byte   new_state    -- 0=ground / 1=glide / 2=fly
--
-- Broadcast range for SM_FLY_STATE updates.
local BROADCAST_RANGE = 100.0

-- FP drain rates (per tick) — 20 tps game loop.
-- GLIDE: 5 FP/sec → 0.25 per tick. FLY: 20 FP/sec → 1.0 per tick.
local DRAIN_GLIDE = 0.25
local DRAIN_FLY   = 1.0

flight = {}

flight.STATE_GROUND = 0
flight.STATE_GLIDE  = 1
flight.STATE_FLY    = 2

-- --------------------------------------------------------
-- flight.get_state(eid) -> state_int
-- --------------------------------------------------------
flight.get_state = function(eid)
    return entity.get_stat(eid, "flight_state") or 0
end

-- --------------------------------------------------------
-- flight.is_airborne(eid) -> bool
-- --------------------------------------------------------
flight.is_airborne = function(eid)
    local s = flight.get_state(eid)
    return s == flight.STATE_GLIDE or s == flight.STATE_FLY
end

-- --------------------------------------------------------
-- Internal: build SM_FLY_STATE (0x74) packet for entity+state.
-- --------------------------------------------------------
local function build_state_packet(eid, state)
    local buf = bytes.new()
    buf:write_int32(eid)
    buf:write_byte(state)
    return buf:to_string()
end

-- --------------------------------------------------------
-- flight.broadcast_state(eid, state)
-- Sends SM_FLY_STATE to the player and all nearby observers.
-- --------------------------------------------------------
flight.broadcast_state = function(eid, state)
    local pkt = build_state_packet(eid, state)

    local gw = entity.get_gateway_id(eid)
    if gw then player.send_packet(gw, 0x74, pkt) end

    for _, nid in ipairs(entity.get_nearby_players(eid, BROADCAST_RANGE)) do
        local ngw = entity.get_gateway_id(nid)
        if ngw then player.send_packet(ngw, 0x74, pkt) end
    end
end

-- Movement speed (m/s) per flight state. Read by anti_cheat.check_move via
-- ECS stat "base_speed". 11.0 is the保守 ground/mount cap; FLY at 15.0 mirrors
-- AION 5.8 wing-flight authoritative speed (glide reuses ground cap because
-- glide is momentum-driven, no powered acceleration).
local SPEED_GROUND = 11.0
local SPEED_FLY    = 15.0

-- --------------------------------------------------------
-- flight.set_state(eid, new_state)
-- Mutates ECS "flight_state" and broadcasts the change.
-- Also injects per-state ECS stat "base_speed" so anti_cheat.check_move
-- reads the correct cap (15 m/s while FLY, 11 m/s on ground/glide).
-- Does NOT consume FP — use flight.takeoff / flight.land for full transitions.
-- --------------------------------------------------------
flight.set_state = function(eid, new_state)
    entity.set_stat(eid, "flight_state", new_state)
    -- 速度上限随状态切换：powered FLY 拔高到 15；GROUND/GLIDE 复位到 11。
    if new_state == flight.STATE_FLY then
        entity.set_stat(eid, "base_speed", SPEED_FLY)
    else
        entity.set_stat(eid, "base_speed", SPEED_GROUND)
    end
    flight.broadcast_state(eid, new_state)
end

-- --------------------------------------------------------
-- flight.takeoff(eid) -> ok, reason
--   "dead"      — entity is dead
--   "no_fp"     — FP below minimum threshold (50) to take off
--   "already"   — already flying
-- On success sets state=FLY and broadcasts SM_FLY_STATE.
-- --------------------------------------------------------
flight.takeoff = function(eid)
    if entity.get_stat(eid, "dead") > 0 then
        return false, "dead"
    end
    if flight.get_state(eid) == flight.STATE_FLY then
        return false, "already"
    end
    local fp = entity.get_stat(eid, "fp") or 0
    if fp < 50 then
        return false, "no_fp"
    end
    flight.set_state(eid, flight.STATE_FLY)
    return true
end

-- --------------------------------------------------------
-- flight.land(eid) -> ok
-- Forces the entity to the ground regardless of current state.
-- --------------------------------------------------------
flight.land = function(eid)
    if flight.get_state(eid) == flight.STATE_GROUND then
        return true
    end
    flight.set_state(eid, flight.STATE_GROUND)
    return true
end

-- --------------------------------------------------------
-- flight.glide_start(eid) -> ok, reason
-- Enters glide from ground (typically triggered by the client jump+hold).
-- --------------------------------------------------------
flight.glide_start = function(eid)
    if entity.get_stat(eid, "dead") > 0 then
        return false, "dead"
    end
    if flight.get_state(eid) ~= flight.STATE_GROUND then
        return false, "already_airborne"
    end
    flight.set_state(eid, flight.STATE_GLIDE)
    return true
end

-- --------------------------------------------------------
-- flight.glide_end(eid) -> ok
-- Lands the entity if currently gliding. No-op otherwise.
-- --------------------------------------------------------
flight.glide_end = function(eid)
    if flight.get_state(eid) == flight.STATE_GLIDE then
        flight.set_state(eid, flight.STATE_GROUND)
    end
    return true
end

-- --------------------------------------------------------
-- flight.drain(eid) -> is_still_airborne
-- Called from on_tick every game tick for airborne players.
-- Decreases FP by the state-appropriate rate; force-lands at 0 FP.
-- Returns false if the entity was forced to land this tick.
-- --------------------------------------------------------
flight.drain = function(eid)
    local state = flight.get_state(eid)
    if state == flight.STATE_GROUND then
        return false  -- not airborne; caller should skip
    end

    local drain = (state == flight.STATE_FLY) and DRAIN_FLY or DRAIN_GLIDE
    local fp    = entity.get_stat(eid, "fp") or 0
    local new_fp = fp - drain

    if new_fp <= 0 then
        entity.set_stat(eid, "fp", 0)
        flight.set_state(eid, flight.STATE_GROUND)
        log.info("flight.drain: force-land entity=" .. tostring(eid) .. " (FP depleted)")
        return false
    end

    entity.set_stat(eid, "fp", new_fp)
    return true
end
