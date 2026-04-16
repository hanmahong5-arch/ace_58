-- scripts/handlers/cm_group_accept.lua
-- CM_GROUP_ACCEPT (0x61): invitee accepts a pending party invitation.
--
-- Payload: empty.
--
-- On success, group.accept() broadcasts SM_GROUP_INFO (0x63) to all members.
-- On failure, the accepting player gets a system-channel explanation.

register_handler(0x61, function(ctx, payload)
    if not group then
        log.warn("CM_GROUP_ACCEPT: group library not loaded")
        return
    end

    local ok, reason = group.accept(ctx.entity_id)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Cannot accept: " .. tostring(reason))
        return
    end

    log.info("CM_GROUP_ACCEPT: entity=" .. tostring(ctx.entity_id) .. " joined")
end)
