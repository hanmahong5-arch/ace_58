-- scripts/events/on_mail_deliver.lua
-- Phase S-18: called by the river MailDeliverWorker via LuaInvoker when a
-- system mail (compensation reward, auction payout, event prize) needs to
-- be persisted.
--
-- Contract:
--   on_mail_deliver(sender_cid, recipient_cid, subject, body,
--                   item_id, item_count, kinah)
--
-- Real SP: aion_mailwritesys_20111227 — the 13-arg system-mail writer from
-- the NCSoft catalog (procedures line 17161). Signature:
--   (p_to_id int, p_to_name varchar(20), p_from_id int, p_from_name varchar(20),
--    p_title varchar(20), p_content varchar(1000),
--    p_item_id bigint, p_item_nameid int, p_item_amount bigint,
--    p_money bigint, p_warehouse int, p_arrive_time int, p_express_mail int)
-- Returns void. Side effect: INSERT into user_mail; if p_item_id<>0 also
-- transfers that user_item row's char_id + warehouse to the recipient.
--
-- This worker runs OUTSIDE a game session (no gateway seq_id, no live ECS
-- entity for recipient) — the SP is the entirety of the work. Names
-- ("sender_cid"/"recipient_cid" suffix = char_id in NCSoft jargon) are
-- passed as bare integers; the NCSoft schema requires display names too,
-- but Phase S-17 worker only has the IDs, so we pass empty strings for
-- p_to_name/p_from_name. A follow-up can hydrate names from user_data if
-- clients show "(unknown)" for the mail envelope.

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

    -- Current time as epoch-seconds int32; NCSoft stores arrive_time as
    -- unix-seconds so the client countdown renders correctly.
    local arrive_time = os.time()

    -- Truncate subject/body defensively: the SP columns are varchar(20) and
    -- varchar(1000); PG rejects oversized input rather than silently trimming.
    local title = tostring(subject or "")
    if #title > 20 then title = string.sub(title, 1, 20) end
    local content = tostring(body or "")
    if #content > 1000 then content = string.sub(content, 1, 1000) end

    local _, err = db.call("aion_mailwritesys_20111227",
        recipient_cid,      -- p_to_id
        "",                 -- p_to_name (unknown in worker context)
        sender_cid or 0,    -- p_from_id (0 = system sender)
        "",                 -- p_from_name
        title,              -- p_title
        content,            -- p_content
        item_id or 0,       -- p_item_id (0 = no attachment)
        0,                  -- p_item_nameid (unused when no item)
        item_count or 0,    -- p_item_amount
        kinah or 0,         -- p_money
        2,                  -- p_warehouse: 2 = mail attachment slot
        arrive_time,        -- p_arrive_time
        0)                  -- p_express_mail: 0 = normal, 1 = express
    if err then
        log.warn("on_mail_deliver: SP err=" .. tostring(err))
    end
end
