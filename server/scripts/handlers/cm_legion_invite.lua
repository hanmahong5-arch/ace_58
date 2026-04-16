-- scripts/handlers/cm_legion_invite.lua
-- CM_LEGION_INVITE (0xB1): legion officer invites another player.
--
-- Payload (LE, unverified):
--   int32       target_entity_id (0 if unknown)
--   utf16_null  target_char_name (fallback)
--
-- Resolves target by eid first, then by name. On success stores a pending
-- invite that the target accepts with CM_LEGION_ACCEPT.

local function read_utf16_null(r)
    local chars = {}
    while r:remaining() >= 2 do
        local code = r:read_int16()
        if code == 0 then break end
        if code < 0x80 then
            chars[#chars + 1] = string.char(code)
        else
            chars[#chars + 1] = "?"
        end
    end
    return table.concat(chars)
end

register_handler(0xB1, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_INVITE: legion library not loaded")
        return
    end

    local target_eid  = payload:read_int32()
    local target_name = read_utf16_null(payload)

    if target_eid == 0 and target_name ~= "" then
        target_eid = player.find_by_name(target_name)
    end
    if target_eid == 0 then
        chat.send_system(ctx.gateway_seq_id,
            "Legion invite failed: target not online.")
        return
    end

    local ok, reason = legion.invite(ctx.entity_id, target_eid)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Legion invite failed: " .. tostring(reason))
        return
    end

    -- Notify the target. A real SM_LEGION_INVITE packet is pending capture;
    -- a system chat message prompt works for the dev loop.
    local leg = legion.get(ctx.entity_id)
    local inviter_name = player.get_name(ctx.gateway_seq_id)
    if inviter_name == "" then inviter_name = "?" end
    local target_gw = entity.get_gateway_id(target_eid)
    if target_gw then
        chat.send_system(target_gw,
            inviter_name .. " invites you to legion ["
            .. (leg and leg.name or "?") .. "]. (type /legion accept)")
    end

    log.info("CM_LEGION_INVITE: inviter=" .. tostring(ctx.entity_id)
        .. " target=" .. tostring(target_eid))
end)
