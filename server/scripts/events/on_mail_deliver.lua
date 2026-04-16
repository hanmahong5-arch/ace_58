-- scripts/events/on_mail_deliver.lua
-- Phase S-17: called by the river MailDeliverWorker via LuaInvoker when a
-- system mail (compensation reward, auction payout, event prize) needs to
-- be persisted.
--
-- Contract:
--   on_mail_deliver(sender_cid, recipient_cid, subject, body,
--                   item_id, item_count, kinah)
--
-- Phase S-17 scope is a structured log + SP call skeleton. The SP signature
-- matches Phase S-14 mail.lua's aion_InsertMailUser. Unlike mail.lua's
-- player-facing send path, this worker runs OUTSIDE a game session, so
-- there is no sender gateway or online notification — the SP is the
-- entirety of the work.

function on_mail_deliver(sender_cid, recipient_cid, subject, body,
                         item_id, item_count, kinah)
    log.info("on_mail_deliver"
        .. " sender=" .. tostring(sender_cid)
        .. " recipient=" .. tostring(recipient_cid)
        .. " item_id=" .. tostring(item_id)
        .. " count=" .. tostring(item_count)
        .. " kinah=" .. tostring(kinah))

    if not db then
        log.warn("on_mail_deliver: db unavailable, dropping mail")
        return
    end
    local _, err = db.call("aion_InsertMailUser",
        sender_cid, recipient_cid,
        subject or "", body or "",
        item_id or 0, item_count or 0, kinah or 0)
    if err then
        log.warn("on_mail_deliver: SP err=" .. tostring(err))
    end
end
