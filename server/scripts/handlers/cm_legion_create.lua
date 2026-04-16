-- scripts/handlers/cm_legion_create.lua
-- CM_LEGION_CREATE (0xB0): player founds a new legion.
--
-- Payload (LE, unverified):
--   utf16_null legion_name   -- max 24 code units
--
-- On success the founder becomes the Brigade General and broadcast receives
-- SM_LEGION_INFO (0xB6). Failures are reported via system chat.

-- Inline UTF-16 reader (same as cm_chat.lua; kept local to avoid global leak).
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

register_handler(0xB0, function(ctx, payload)
    if not legion then
        log.warn("CM_LEGION_CREATE: legion library not loaded")
        return
    end

    local name = read_utf16_null(payload)
    if name == "" then
        chat.send_system(ctx.gateway_seq_id, "Legion name required.")
        return
    end

    local ok, reason_or_id = legion.create(ctx.entity_id, name)
    if not ok then
        chat.send_system(ctx.gateway_seq_id,
            "Legion creation failed: " .. tostring(reason_or_id))
        return
    end

    log.info("CM_LEGION_CREATE: entity=" .. tostring(ctx.entity_id)
        .. " legion_id=" .. tostring(reason_or_id) .. " name=" .. name)
end)
