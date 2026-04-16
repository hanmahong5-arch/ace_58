-- scripts/handlers/cm_mail_list.lua
-- CM_MAIL_LIST (0xBF): client requests its inbox.
--
-- Payload: empty.
-- Server responds with SM_MAIL_LIST (0xC3):
--   int32 count
--   for each mail:
--     int64      mail_id
--     utf16_null sender_name
--     utf16_null subject
--     byte       is_read
--     byte       has_attachment
--     int64      sent_ts_unix

register_handler(0xBF, function(ctx, payload)
    if not mail then
        log.warn("CM_MAIL_LIST: mail lib not loaded, dropping")
        return
    end

    local rows = mail.list(ctx.entity_id)
    local count = (rows and #rows) or 0

    local buf = bytes.new()
    buf:write_int32(count)
    for _, row in ipairs(rows or {}) do
        local mid         = tonumber(row.mail_id    or row.id        or 0) or 0
        local sender_name = tostring(row.sender_name or row.sender   or "?")
        local subject     = tostring(row.subject    or "")
        local is_read     = (tonumber(row.is_read   or row.read_flag or 0) or 0) > 0
        local has_attach  = (tonumber(row.has_attachment
                                      or row.attached_item_id
                                      or row.attached_kinah        or 0) or 0) > 0
        local sent_ts     = tonumber(row.sent_ts    or row.sent_unix
                                      or row.created_at            or 0) or 0

        buf:write_int64(mid)
        buf:write_string_utf16(sender_name)
        buf:write_string_utf16(subject)
        buf:write_byte(is_read    and 1 or 0)
        buf:write_byte(has_attach and 1 or 0)
        buf:write_int64(sent_ts)
    end

    player.send_packet(ctx.gateway_seq_id, 0xC3, buf:to_string())
    log.info("CM_MAIL_LIST: entity=" .. tostring(ctx.entity_id)
        .. " count=" .. tostring(count))
end)
