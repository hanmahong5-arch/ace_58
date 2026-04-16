-- scripts/handlers/cm_mail_delete.lua
-- CM_MAIL_DELETE (0xC2): client permanently removes a mail from the inbox.
--
-- Payload (LE):
--   int64 mail_id

register_handler(0xC2, function(ctx, payload)
    if not mail then
        log.warn("CM_MAIL_DELETE: mail lib not loaded, dropping")
        return
    end
    local mail_id = payload:read_int64()

    local ok, reason = mail.delete(ctx.entity_id, mail_id)
    if not ok then
        log.info("CM_MAIL_DELETE: rejected entity=" .. tostring(ctx.entity_id)
            .. " mail_id=" .. tostring(mail_id)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_MAIL_DELETE: ok entity=" .. tostring(ctx.entity_id)
        .. " mail_id=" .. tostring(mail_id))
end)
