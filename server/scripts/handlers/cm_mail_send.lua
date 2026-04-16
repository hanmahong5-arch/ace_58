-- scripts/handlers/cm_mail_send.lua
-- CM_MAIL_SEND (0xBE): client composes and sends an in-game mail.
--
-- Payload (LE):
--   utf16_null recipient_name
--   utf16_null subject
--   utf16_null body
--   int32      attached_item_id       -- 0 = none
--   int32      attached_item_count    -- ignored when item_id == 0
--   int64      attached_kinah         -- 0 = none

-- Inline UTF-16 null reader (same pattern as cm_chat.lua).
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

register_handler(0xBE, function(ctx, payload)
    if not mail then
        log.warn("CM_MAIL_SEND: mail lib not loaded, dropping")
        return
    end
    -- Dead players cannot send mail (matches client-side grayout).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local recipient = read_utf16_null(payload)
    local subject   = read_utf16_null(payload)
    local body      = read_utf16_null(payload)
    local item_id   = payload:read_int32()
    local item_cnt  = payload:read_int32()
    local kinah     = payload:read_int64()

    local ok, reason = mail.send(ctx.entity_id, recipient, subject, body,
        item_id, item_cnt, kinah)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Mail send failed: " .. tostring(reason))
        end
        log.info("CM_MAIL_SEND: rejected entity=" .. tostring(ctx.entity_id)
            .. " to=" .. tostring(recipient)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_MAIL_SEND: ok entity=" .. tostring(ctx.entity_id)
        .. " to=" .. tostring(recipient))
end)
