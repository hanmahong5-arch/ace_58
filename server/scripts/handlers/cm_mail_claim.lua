-- scripts/handlers/cm_mail_claim.lua
-- CM_MAIL_CLAIM (0xC1): client takes the attached item / kinah from a mail.
--
-- Payload (LE):
--   int64 mail_id

register_handler(0xC1, function(ctx, payload)
    if not mail then
        log.warn("CM_MAIL_CLAIM: mail lib not loaded, dropping")
        return
    end
    -- Dead players cannot claim attachments (matches client-side block).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local mail_id = payload:read_int64()
    local ok, reason = mail.claim(ctx.entity_id, mail_id)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Mail claim failed: " .. tostring(reason))
        end
        log.info("CM_MAIL_CLAIM: rejected entity=" .. tostring(ctx.entity_id)
            .. " mail_id=" .. tostring(mail_id)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_MAIL_CLAIM: ok entity=" .. tostring(ctx.entity_id)
        .. " mail_id=" .. tostring(mail_id))
end)
