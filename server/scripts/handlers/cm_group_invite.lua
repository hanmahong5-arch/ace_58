-- scripts/handlers/cm_group_invite.lua
-- CM_GROUP_INVITE (0x60): leader invites another player to their party.
--
-- Payload (LE, unverified):
--   int32       target_entity_id     -- preferred — client knows the target's eid
--   utf16_null  target_name          -- fallback when eid is 0 / unknown
--
-- Behaviour:
--   • Resolves the target (by eid first, then by name lookup).
--   • Calls group.invite(leader_eid, target_eid); stores a pending invite.
--   • On success, notifies the target via SM_CHAT system message prompting them
--     to accept. (A proper SM_GROUP_INVITE prompt is pending packet capture.)
--   • On failure, sends the leader a system-channel explanation.

register_handler(0x60, function(ctx, payload)
    if not group then
        log.warn("CM_GROUP_INVITE: group library not loaded")
        return
    end

    local target_eid = payload:read_int32()

    -- Inline UTF-16 reader (same logic as cm_chat.lua).
    local target_name
    do
        local chars = {}
        while payload:remaining() >= 2 do
            local code = payload:read_int16()
            if code == 0 then break end
            if code < 0x80 then
                chars[#chars + 1] = string.char(code)
            else
                chars[#chars + 1] = "?"
            end
        end
        target_name = table.concat(chars)
    end

    -- Fallback: resolve name if eid was not provided.
    if target_eid == 0 and target_name ~= "" then
        target_eid = player.find_by_name(target_name)
    end

    if target_eid == 0 then
        chat.send_system(ctx.gateway_seq_id,
            "Invite failed: target '" .. target_name .. "' not found.")
        return
    end

    local ok, reason = group.invite(ctx.entity_id, target_eid)
    if not ok then
        chat.send_system(ctx.gateway_seq_id, "Invite failed: " .. tostring(reason))
        return
    end

    -- Notify the target with a system message (pending SM_GROUP_INVITE packet format).
    local leader_name = player.get_name(ctx.gateway_seq_id)
    if leader_name == "" then leader_name = "?" end
    local target_gw = entity.get_gateway_id(target_eid)
    if target_gw then
        chat.send_system(target_gw,
            leader_name .. " invites you to a party. (type /accept)")
    end

    log.info("CM_GROUP_INVITE: leader=" .. tostring(ctx.entity_id)
        .. " target=" .. tostring(target_eid))
end)
