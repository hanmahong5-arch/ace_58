-- scripts/handlers/cm_legion_accept.lua
-- CM_LEGION_ACCEPT (0xB2): target accepts a pending legion invitation.
-- Payload: empty.

register_handler(0xB2, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_ACCEPT: legion library not loaded")
        return
    end

    local ok, reason = legion.accept(ctx.entity_id)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Cannot join legion: " .. tostring(reason))
        return
    end

    log.info("CM_LEGION_ACCEPT: entity=" .. tostring(ctx.entity_id) .. " joined")
end)
