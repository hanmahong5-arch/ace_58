-- scripts/handlers/cm_legion_kick.lua
-- CM_LEGION_KICK (0xB4): Brigade General expels a member from the legion.
--
-- Payload (LE, unverified):
--   utf16_null target_char_name

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

register_handler(0xB4, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_KICK: legion library not loaded")
        return
    end

    local target_name = read_utf16_null(payload)
    if target_name == "" then
        chat.send_system(ctx.gateway_seq_id, "Kick target required.")
        return
    end

    local ok, reason = legion.kick(ctx.entity_id, target_name)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Kick failed: " .. tostring(reason))
        return
    end

    chat.send_system(ctx.gateway_seq_id, target_name .. " has been removed.")
    log.info("CM_LEGION_KICK: kicker=" .. tostring(ctx.entity_id)
        .. " target_name=" .. target_name)
end)
