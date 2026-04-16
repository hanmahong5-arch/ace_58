-- scripts/handlers/cm_legion_leave.lua
-- CM_LEGION_LEAVE (0xB3): member voluntarily leaves their legion.
-- Payload: empty. The Brigade General cannot leave — they must disband first.

register_handler(0xB3, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_LEAVE: legion library not loaded")
        return
    end

    local ok, reason = legion.leave(ctx.entity_id)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Cannot leave legion: " .. tostring(reason))
        return
    end

    chat.send_system(ctx.gateway_seq_id, "You have left your legion.")
    log.info("CM_LEGION_LEAVE: entity=" .. tostring(ctx.entity_id))
end)
