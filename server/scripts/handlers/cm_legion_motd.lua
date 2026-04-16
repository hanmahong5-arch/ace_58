-- scripts/handlers/cm_legion_motd.lua
-- CM_LEGION_MOTD (0xB5): officer sets the legion's message of the day.
--
-- Payload (LE, unverified):
--   utf16_null motd (max 256 UTF-16 code units)

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

register_handler(0xB5, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_MOTD: legion library not loaded")
        return
    end

    local motd = read_utf16_null(payload)

    local ok, reason = legion.set_motd(ctx.entity_id, motd)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "MOTD change failed: " .. tostring(reason))
        return
    end

    log.info("CM_LEGION_MOTD: entity=" .. tostring(ctx.entity_id)
        .. " motd_len=" .. tostring(#motd))
end)
