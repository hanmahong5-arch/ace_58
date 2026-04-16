-- scripts/handlers/cm_flight_path_select.lua
-- CM_FLIGHT_PATH_SELECT (0x75): player picked a flight-path destination
-- from the Flight Master's dialog window.
--
-- Payload (LE, unverified):
--   int32  destination_id   -- index into _active_flight_paths[ctx.entity_id]
--
-- Flight paths are cached per-player by the Flight Master NPC's dialog
-- handler, mirroring the _active_shops and _active_teleports patterns.
--
-- On success:
--   1. Charge flight fee (kinah).
--   2. Force takeoff (state = FLY) and broadcast SM_FLY_STATE.
--   3. Emit SM_FLIGHT_PATH_START with destination coordinates so the client
--      runs its scripted flight cinematic.
--   4. Server-side teleport to destination with ECS set_position (the client
--      is expected to animate the arc locally).

_active_flight_paths = _active_flight_paths or {}  -- entity_id -> {[id]={name,x,y,z,price}}

register_handler(0x75, function(ctx, payload)
    local dst_id = payload:read_int32()

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        chat.send_system(ctx.gateway_seq_id, "Cannot fly while dead.")
        return
    end

    local paths = _active_flight_paths[ctx.entity_id]
    if not paths then
        chat.send_system(ctx.gateway_seq_id, "No active flight master.")
        return
    end

    local dst = paths[dst_id]
    if not dst then
        chat.send_system(ctx.gateway_seq_id, "Unknown flight destination.")
        return
    end

    -- Charge fee first so a failed kinah check doesn't leak state.
    if dst.price and dst.price > 0 then
        if not player.spend_kinah(ctx.gateway_seq_id, dst.price) then
            chat.send_system(ctx.gateway_seq_id, "Not enough kinah.")
            return
        end
    end

    -- Force flight state so the client animates the takeoff.
    if flight then
        flight.set_state(ctx.entity_id, flight.STATE_FLY)
    end

    -- Relocate in ECS. The client animates an arc from current→destination
    -- based on SM_FLIGHT_PATH_START; final position sync is via SM_TELEPORT_LOC
    -- after arrival.
    entity.set_position(ctx.entity_id, dst.x, dst.y, dst.z, 0)

    -- SM_FLIGHT_PATH_START (0x76) payload (LE, unverified):
    --   int32 entity_id, int32 path_id, float x, float y, float z
    local buf = bytes.new()
    buf:write_int32(ctx.entity_id)
    buf:write_int32(dst_id)
    buf:write_float32(dst.x)
    buf:write_float32(dst.y)
    buf:write_float32(dst.z)
    player.send_packet(ctx.gateway_seq_id, 0x76, buf:to_string())

    -- Clear session so a second click doesn't replay.
    _active_flight_paths[ctx.entity_id] = nil

    log.info("CM_FLIGHT_PATH_SELECT: entity=" .. tostring(ctx.entity_id)
        .. " dst=" .. tostring(dst.name or dst_id))
end)
