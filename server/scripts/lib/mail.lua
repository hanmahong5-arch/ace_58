-- scripts/lib/mail.lua
-- Phase S-14: in-game mail state machine.
--
-- Responsibilities:
--   * Validate outgoing mail (length caps, recipient existence, send fee).
--   * Persist mail via the real NCSoft stored procedures (Round 13 rename).
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
-- SP wiring (Round 13 — rename from Lua-invented to real NCSoft names):
--   send    -> aion_mailwrite_20160804     (00133 — player-to-player; system mail
--                                            uses 00031 aion_mailwritesys_20111227 via jobq)
--   list    -> aion_maillist                (00045)  args: char_id, now_time, max_mail
--   read    -> aion_mailread                (00046)  args: char_id, mail_id; marks read + returns body
--   claim   -> aion_mailgetitem             (00132)  args: char_id, mail_id, warehouse, flag(0=item/1=money/2=ap)
--   delete  -> aion_maildelete              (00048)  args: char_id, mail_id
--   resolve -> aion_getcharidbyname         (00130)  args: name
--
-- This module is deliberately synchronous: player-initiated sends write
-- directly through db.call. System mail (compensation, event rewards,
-- auction-house refunds) uses jobq.enqueue with kind "aion58.mail.deliver"
-- — the S-13 river worker calls aion_mailwritesys_20111227 inside the
-- worker tx for at-least-once delivery.

mail = {}

mail.MAX_SUBJECT_LEN     = 80
mail.MAX_BODY_LEN        = 1024
mail.MAX_ATTACHED_COUNT  = 9999
mail.SEND_FEE            = 10       -- kinah; NCSoft default for standard mail
mail.MAX_INBOX_PAGE      = 100      -- aion_maillist's TOP cap (NCSoft 用 100)

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

    -- Recipient must be an existing character. Resolve via aion_getcharidbyname
    -- (00130, PG-only, see SP rationale). Online-fallback covers the rare case
    -- where DB lookup misses (e.g. very fresh character not yet flushed).
    local recipient_char_id = 0
    if db then
        local rows, rerr = db.call("aion_getcharidbyname", recipient_name)
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

    -- Persist via aion_mailwrite_20160804 (00133, NCSoft signature):
    --   (to_id, to_name, from_id, from_name, title, content,
    --    item_id, item_nameid, item_amount, money, abyss_point,
    --    warehouse, arrive_time, express_mail) -> RETURNS BIGINT mail_id
    -- 系统邮件（补偿/活动奖励）走 jobq + aion_mailwritesys_20111227。
    local mail_id = 0
    if db then
        -- arrive_time = now（玩家邮件即时送达；系统邮件可后置）；
        -- warehouse=2 (cube/inbox attach)；item_nameid=0 (TODO: 待 lookup item 模板)；
        -- abyss_point=0 (玩家邮件不附 AP)；express_mail=0 (普通邮件)。
        local now_ts = os.time()
        local rows, serr = db.call("aion_mailwrite_20160804",
            recipient_char_id, recipient_name,
            sender_char_id, sender_name,
            subject, body,
            item_id, 0, item_count, kinah, 0,
            2, now_ts, 0)
        if serr then
            -- Roll back the fee so the sender does not lose kinah to a DB outage.
            if total_cost > 0 then
                player.add_kinah(sender_gw, total_cost)
            end
            log.warn("mail.send: SP failed err=" .. tostring(serr))
            return false, "sp_failed"
        end
        -- aion_mailwrite_20160804 在 NCSoft 不返回 id；本端 PG 端按惯例可让 SP
        -- RETURNS BIGINT；若运行时未拿到 id，仍允许 SM_MAIL_NEW 推送（id=0）。
        if rows and #rows > 0 then
            local r = rows[1]
            mail_id = tonumber(r.mail_id or r.id or r[1] or 0) or 0
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
-- aion_maillist (00045) 签名: (char_id, now_time, max_mail) → 9 列 row。
mail.list = function(reader_eid)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return {}
    end
    local rows, err = db.call("aion_maillist", char_id, os.time(), mail.MAX_INBOX_PAGE)
    if err or not rows then
        if err then log.warn("mail.list: SP err=" .. tostring(err)) end
        return {}
    end
    return rows
end

-- --- mail.read -----------------------------------------------------------

-- Marks a mail as read and returns the row table.
-- aion_mailread (00046) 内部先 UPDATE state=1 再 SELECT 完整 body（13 列）。
mail.read = function(reader_eid, mail_id)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end
    local rows, err = db.call("aion_mailread", char_id, mail_id)
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

-- Claim the attachment of a mail. NCSoft 设计是一次只领一类（item/money/ap），
-- 由 flag 控制（aion_mailgetitem 00132，4 args，rc + out_item_id/money/ap）。
-- 客户端 CM_MAIL_CLAIM 0xC1 的 payload 当前只带 mail_id，没有 flag —
-- 我们顺序尝试 item → money → ap，每次只领一种已存在的资产，发回结果给玩家。
-- 这保留了 NCSoft "rc=2 表示该类无附件" 的语义，又不要求 client 改 packet。
mail.claim = function(reader_eid, mail_id)
    local gw = entity.get_gateway_id(reader_eid)
    if not gw then return false, "not_found" end

    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end

    -- NCSoft warehouse 编号约定（与 lib/warehouse.lua + 00037 + 00134 一致）：
    -- 0 = inventory (cube), 1 = char warehouse, 2 = account warehouse。
    -- 邮件附件领取 → 进玩家背包 (cube)。
    local WAREHOUSE_CUBE = 0

    -- 单次 SP 调用：按 flag 取一类资产；rc=0 success / 1 invalid_key / 2 no_asset。
    local function _try(flag)
        local rows, err = db.call("aion_mailgetitem",
            char_id, mail_id, WAREHOUSE_CUBE, flag)
        if err then
            log.warn("mail.claim: SP err flag=" .. tostring(flag) .. " err=" .. tostring(err))
            return nil, "sp_failed"
        end
        if not rows or #rows == 0 then
            return nil, "not_found"
        end
        local r = rows[1]
        return {
            rc      = tonumber(r.rc          or r[1] or -1) or -1,
            item_id = tonumber(r.out_item_id or r[2] or 0)  or 0,
            money   = tonumber(r.out_money   or r[3] or 0)  or 0,
            ap      = tonumber(r.out_ap      or r[4] or 0)  or 0,
        }
    end

    -- 1) 先试 item (flag=0)
    local res, reason = _try(0)
    if not res then return false, reason end
    if res.rc == 1 then
        return false, "not_found"
    end

    local granted = false
    if res.rc == 0 and res.item_id > 0 then
        -- aion_mailgetitem 已把 user_item.warehouse 切到 cube 完成 DB 转移；
        -- 仍调 player.add_item 同步 world 的 entity inventory 缓存（不重复 INSERT，
        -- 仅更新该玩家的 in-memory 物品索引）。amount 走 1：邮件 item 在 NCSoft
        -- 模型里大多 stack=1，stack 物品（药/材料）走 SM_INVENTORY_INFO 全量推送
        -- 在 Round 14+ 重写，先按 1 处理（暴露问题再修）。
        player.add_item(gw, res.item_id, 1)
        granted = true
        log.info("mail.claim: item transferred char_id=" .. char_id
            .. " mail_id=" .. mail_id .. " item_id=" .. res.item_id)
    end

    -- 2) 试 money (flag=1)
    res, reason = _try(1)
    if not res then return false, reason end
    if res.rc == 0 and res.money > 0 then
        player.add_kinah(gw, res.money)
        granted = true
        log.info("mail.claim: kinah granted char_id=" .. char_id
            .. " mail_id=" .. mail_id .. " kinah=" .. res.money)
    end

    -- 3) 试 abyss_point (flag=2)
    res, reason = _try(2)
    if not res then return false, reason end
    if res.rc == 0 and res.ap > 0 then
        if player.add_abyss_point then
            player.add_abyss_point(gw, res.ap)
        end
        granted = true
        log.info("mail.claim: ap granted char_id=" .. char_id
            .. " mail_id=" .. mail_id .. " ap=" .. res.ap)
    end

    if not granted then
        return false, "already_claimed"
    end
    return true, nil
end

-- --- mail.delete ---------------------------------------------------------

-- aion_maildelete (00048) 返回 (rc, prev_state)。rc=1 表示 mail 不属于 caller。
mail.delete = function(reader_eid, mail_id)
    local char_id = _char_id_of(reader_eid)
    if char_id == 0 or not db then
        return false, "sp_failed"
    end
    local rows, err = db.call("aion_maildelete", char_id, mail_id)
    if err then
        log.warn("mail.delete: SP err=" .. tostring(err))
        return false, "sp_failed"
    end
    if rows and #rows > 0 then
        local rc = tonumber(rows[1].rc or rows[1][1] or 0) or 0
        if rc == 1 then return false, "not_found" end
    end
    return true, nil
end
