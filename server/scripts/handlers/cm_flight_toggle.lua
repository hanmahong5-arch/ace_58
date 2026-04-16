-- scripts/handlers/cm_flight_toggle.lua
-- CM_FLIGHT_TOGGLE (0x71): player pressed the flight key.
--
-- Payload: empty.
--
-- Toggles GROUND ↔ FLY. Sends a system message on failure so the client
-- shows a reason (no FP, dead, already flying, etc.).

register_handler(0x71, function(ctx, payload)
    if not flight then
        log.warn("CM_FLIGHT_TOGGLE: flight library not loaded")
        return
    end

    local state = flight.get_state(ctx.entity_id)
    local ok, reason

    if state == flight.STATE_FLY then
        ok, reason = flight.land(ctx.entity_id)
    else
        ok, reason = flight.takeoff(ctx.entity_id)
    end

    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Cannot toggle flight: " .. tostring(reason))
    end
end)
