-- scripts/handlers/cm_pvp_flag.lua
-- CM_PVP_FLAG_TOGGLE (0xB8): client toggles its PvP participation flag.
--
-- Payload: none (empty body — the toggle is implicit).
--
-- Effect:
--   1. Flip the cached ECS "pvp_flag" stat via pvp.toggle_flag.
--   2. Broadcast SM_PVP_FLAG (0xB9) to nearby observers so their clients
--      update the name-plate coloring.
--
-- SM_PVP_FLAG payload (LE): int32 entity_id, byte is_flagged.
--
-- NOTE: opcode 0xB8/0xB9 and payload format unverified; adjust after packet capture.

local BROADCAST_RANGE = 200.0

register_handler(0xB8, function(ctx, payload)
    if not pvp then
        log.warn("CM_PVP_FLAG_TOGGLE: pvp lib not loaded, dropping")
        return
    end

    -- Dead players cannot toggle the flag (prevents respawn exploit cycles).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local now_flagged = pvp.toggle_flag(ctx.entity_id)

    -- Build SM_PVP_FLAG (0xB9) once, reuse for self and observers.
    local buf = bytes.new()
    buf:write_int32(ctx.entity_id)
    buf:write_byte(now_flagged and 1 or 0)
    local pkt = buf:to_string()

    -- Confirm to the actor first.
    player.send_packet(ctx.gateway_seq_id, 0xB9, pkt)

    -- Broadcast to nearby players so they see the flag change.
    local nearby = entity.get_nearby_players(ctx.entity_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local gw = entity.get_gateway_id(nid)
        if gw then
            player.send_packet(gw, 0xB9, pkt)
        end
    end

    log.info("CM_PVP_FLAG_TOGGLE entity=" .. tostring(ctx.entity_id)
        .. " flagged=" .. tostring(now_flagged))
end)
