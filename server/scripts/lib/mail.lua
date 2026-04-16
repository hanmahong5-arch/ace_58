-- scripts/lib/mail.lua
-- Phase S-14: in-game mail state machine.
--
-- Responsibilities:
--   * Validate outgoing mail (length caps, recipient existence, send fee).
--   * Persist mail via NCSoft stored procedures (best-effort names, see TODO).
--   * Fetch / read / delete inbox entries.
--   * Claim attached items and kinah atomically.
--   * Notify live recipients via SM_MAIL_NEW when they are online.
--
-- Contract:
--   mail.send(sender_eid, recipient_name, subject, body,
--             item_id, item_count, kinah) -> ok, reason
--     reasons: "bad_subject" | "bad_body" | "no_recipient" | "no_kinah"
--              | "bad_item_count" | "sp_failed"
--   mail.list(reader_eid) -> array of mail rows
--   mail.read(reader_eid, mail_id) -> ok, row | nil, reason
--     reasons: "sp_failed"
--   mail.claim(reader_eid, mail_id) -> ok, reason
--     reasons: "not_found" | "already_claimed" | "inventory_full" | "sp_failed"
--   mail.delete(reader_eid, mail_id) -> ok, reason
--     reasons: "sp_failed"
--
-- Design notes:
--   - The SP names used here (aion_InsertMailUser / aion_GetMailsByUser /
--     aion_UpdateMailRead / aion_ClaimMailAttachment / aion_DeleteMail) are
--     placeholders in the same spirit as S-4 inventory SPs. Verify against
--     the 1314-procedure migration bundle before production use.
--   - This module is deliberately synchronous: player-initiated sends write
--     directly through db.call. System mail (compensation, event rewards,
--     auction-house refunds) should use jobq.enqueue with kind
--     "aion58.mail.deliver" — the S-13 river worker picks those up and calls
--     aion_InsertMailUser inside the worker tx for at-least-once delivery.

mail = {}

mail.MAX_SUBJECT_LEN     = 80
mail.MAX_BODY_LEN        = 1024
mail.MAX_ATTACHED_COUNT  = 9999
mail.SEND_FEE            = 10       -- kinah; NCSoft default for standard mail

-- --- Helpers -------------------------------------------------------------

-- _char_id_of(eid) reads the cached "char_id" stat that cm_enter_world writes.
-- Returns 0 when the entity is not a logged-in player.
local function _char_id_of(eid)
    return math.floor(entity.get_stat(eid, "char_id") or 0)
end

-- _validate_text(s, max_len) -> ok, reason
local function _validate_text(s, max_len, reason_tag)
    if type(s) ~= "string" or #s == 0 then
        return false, reason_tag
    end
    -- #s counts bytes but mail UIs cap by code point. An 80-char subject is
    -- at most 80 * 3 = 240 UTF-8 bytes; any subject over that is definitely
    -- too long regardless of script.
    if #s > (max_len * 3) then
        return false, reason_tag
    end
    return true, nil
end

-- --- mail.send -----------------------------------------------------------

-- Synchronous mail send. Returns ok, reason on failure.
-- Kinah is deducted from the sender even on SP failure rollback — the rollback
-- restores the cached balance via player.add_kinah(fee). Item detachment from
-- the sender's inventory is NOT handled in MVP: item attachments require a
-- follow-up phase with aion_RemoveItemUser in the same tx.
mail.send = function(sender_eid, recipient_name, subject, body,
                     item_id, item_count, kinah)
    -- Text validation first (cheap, no DB).
    local ok, reason = _validate_text(subject, mail.MAX_SUBJECT_LEN, "bad_subject")
    if not ok then return false, reason end
    ok, reason = _validate_text(body, mail.MAX_BODY_LEN, "bad_body")
    if not ok then return false, reason end

    item_id    = tonumber(item_id)    or 0
    item_count = tonumber(item_count) or 0
    kinah      = tonumber(kinah)      or 0
    if item_id > 0 and (item_count <= 0 or item_count > mail.MAX_ATTACHED_COUNT) then
        return false, "bad_item_count"
    end
    if kinah < 0 then kinah = 0 end

    -- Recipient must be an existing character. Resolve via aion_GetCharIdByName
    -- (NCSoft SP — name unverified). If the SP is unavailable fall back to
    -- find_by_name which only returns online players.
    local recipient_char_id = 0
    if db then
        local rows, rerr = db.call("aion_GetCharIdByName", recipient_name)
        if not rerr and rows and #rows > 0 then
            recipient_char_id = tonumber(rows[1].char_id or rows[1].id or 0) or 0
        end
    end
    if recipient_char_id == 0 and player and player.find_by_name then
        local target_eid = player.find_by_name(recipient_name)
        if target_eid ~= 0 then
            recipient_char_id = _char_id_of(target_eid)
        end
    end
    if recipient_char_id == 0 then
        return false, "no_recipient"
    end

    -- Sender must have enough kinah for fee + optional attached kinah.
    local sender_gw = entity.get_gateway_id(sender_eid)
    if not sender_gw then
        return false, "no_kinah"  -- NPC or system mail should use jobq path
    end
    local total_cost = mail.SEND_FEE + kinah
    if total_cost > 0 and not player.spend_kinah(sender_gw, total_cost) then
        return false, "no_kinah"
    end

    local sender_char_id = _char_id_of(sender_eid)
    local sender_name    = player.get_name(sender_gw)
    if sender_name == "" then sender_name = "?" end

    -- Persist. SP signature assumed:
    --   aion_InsertMailUser(sender_char_id, recipient_char_id, subject, body,
    --                       attached_item_id, attached_item_count, attached_kinah)
    -- returning one row with column "mail_id".
    local mail_id = 0
    if db then
        local rows, serr = db.call("aion_InsertMailUser",
            sender_char_id, recipient_char_id, subject, body,
            item_id, item_count, kinah)
        if serr then
            -- Roll back the fee so the sender does not lose kinah to a DB outage.
            if total_cost > 0 then
                player.add_kinah(sender_gw, total_cost)
            end
            log.warn("mail.send: SP failed err=" .. tostring(serr))
            return false, "sp_failed"
        end
        if rows and #rows > 0 then
            mail_id = tonumber(rows[1].mail_id or rows[1].id or 0) or 0
        end
    end

    -- Notify the recipient if they are online.
    if player.find_by_name then
        local target_eid = player.find_by_name(recipient_name)
        if target_eid ~= 0 then
            local target_gw = entity.get_gateway_id(target_eid)
            if target_gw then
                local buf = bytes.new()
                buf:write_int64(mail_id)
                buf:write_string_utf16(sender_name)
                buf:write_string_utf16(subject)
                player.send_packet(target_gw, 0xC4, buf:to_string())
            end
        end
    end

    log.info("mail.send: "
        .. "from=" .. tostring(sender_char_id)
        .. " to=" .. tostring(recipient_char_id)
        .. " mail_id=" .. tostring(mail_id))
    return true, nil
end

-- --- mail.list -----------------------------------------------------------

-- Returns an array of mail row tables. Empty array on SP failure / no mail.
mail.list = function(reader_eid)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return {}
    end
    local rows, err = db.call("aion_GetMailsByUser", char_id)
    if err or not rows then
        if err then log.warn("mail.list: SP err=" .. tostring(err)) end
        return {}
    end
    return rows
end

-- --- mail.read -----------------------------------------------------------

-- Marks a mail as read and returns the row table.
mail.read = function(reader_eid, mail_id)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end
    local rows, err = db.call("aion_UpdateMailRead", char_id, mail_id)
    if err then
        log.warn("mail.read: SP err=" .. tostring(err))
        return false, "sp_failed"
    end
    if not rows or #rows == 0 then
        return false, "not_found"
    end
    return true, rows[1]
end

-- --- mail.claim ----------------------------------------------------------

-- Claim the attachment (item and/or kinah) of a mail. Calls a composite SP
-- aion_ClaimMailAttachment that returns { item_id, item_count, kinah } for
-- the attachment metadata in a single row; on success those are credited to
-- the player via player.add_item / player.add_kinah.
mail.claim = function(reader_eid, mail_id)
    local gw = entity.get_gateway_id(reader_eid)
    if not gw then return false, "not_found" end

    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end
    local rows, err = db.call("aion_ClaimMailAttachment", char_id, mail_id)
    if err then
        log.warn("mail.claim: SP err=" .. tostring(err))
        return false, "sp_failed"
    end
    if not rows or #rows == 0 then
        return false, "not_found"
    end

    local row = rows[1]
    local iid   = tonumber(row.item_id     or 0) or 0
    local icnt  = tonumber(row.item_count  or 0) or 0
    local kinah = tonumber(row.kinah       or 0) or 0

    -- Nothing left on the attachment means someone already claimed it.
    if iid == 0 and kinah == 0 then
        return false, "already_claimed"
    end

    if iid > 0 and icnt > 0 then
        player.add_item(gw, iid, icnt)
    end
    if kinah > 0 then
        player.add_kinah(gw, kinah)
    end

    log.info("mail.claim: char_id=" .. tostring(char_id)
        .. " mail_id=" .. tostring(mail_id)
        .. " item_id=" .. tostring(iid)
        .. " count=" .. tostring(icnt)
        .. " kinah=" .. tostring(kinah))
    return true, nil
end

-- --- mail.delete ---------------------------------------------------------

mail.delete = function(reader_eid, mail_id)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end
    local _, err = db.call("aion_DeleteMail", char_id, mail_id)
    if err then
        log.warn("mail.delete: SP err=" .. tostring(err))
        return false, "sp_failed"
    end
    return true, nil
end
