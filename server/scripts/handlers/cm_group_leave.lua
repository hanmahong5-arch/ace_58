-- scripts/handlers/cm_group_leave.lua
-- CM_GROUP_LEAVE (0x62): player voluntarily leaves the current party.
--
-- Payload: empty.
--
-- If the leaver is the leader, group.leave() promotes the next member.
-- If fewer than 2 members remain afterwards, the group is disbanded.

register_handler(0x62, function(ctx, payload)
    if not group then
        log.warn("CM_GROUP_LEAVE: group library not loaded")
        return
    end

    local ok, reason = group.leave(ctx.entity_id)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Cannot leave: " .. tostring(reason))
        return
    end

    log.info("CM_GROUP_LEAVE: entity=" .. tostring(ctx.entity_id) .. " left")
end)
