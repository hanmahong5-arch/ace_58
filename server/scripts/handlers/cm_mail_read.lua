-- scripts/handlers/cm_mail_read.lua
-- CM_MAIL_READ (0xC0): client opens a mail; server marks it read and the
-- client is expected to render the full body from its own cached list.
-- For Phase S-14 the response is a single SM_MAIL_NEW-shaped notification
-- carrying just the mail id so the client can flip its local is_read flag
-- without a full list refresh.
--
-- Payload (LE):
--   int64 mail_id

register_handler(0xC0, function(ctx, payload)
    if not mail then
        log.warn("CM_MAIL_READ: mail lib not loaded, dropping")
        return
    end
    local mail_id = payload:read_int64()

    local ok, result = mail.read(ctx.entity_id, mail_id)
    if not ok then
        log.info("CM_MAIL_READ: rejected entity=" .. tostring(ctx.entity_id)
            .. " mail_id=" .. tostring(mail_id)
            .. " reason=" .. tostring(result))
        return
    end

    log.info("CM_MAIL_READ: ok entity=" .. tostring(ctx.entity_id)
        .. " mail_id=" .. tostring(mail_id))
end)
