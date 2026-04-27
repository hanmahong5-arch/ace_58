-- scripts/handlers/cm_restore_character.lua
-- CM_RESTORE_CHARACTER (0x18): client cancels a pending soft-delete on a
-- character within the 7-day grace window. The opposite of CM_DELETE_CHARACTER.
--
-- Round 10 (F1) addition: closes the create→list→delete loop. Without this
-- handler, players who clicked "delete" by mistake had no way to recover
-- their character — they had to wait 7 days for the sweeper to actually
-- purge it before they could create a new char with the same name. The
-- restore SP (aion_clearchardeletetime) zeroes user_data.delete_date and
-- bumps change_info_time so character-list refresh sees the char as alive.
--
-- Payload (5.8 client, LE):
--   int32 char_id              -- target character (must be soft-deleted)
--
-- Response: SM_RESTORE_CHARACTER_RESPONSE (0x19):
--   byte  result               -- 0=OK, 1=not_owner, 2=not_found,
--                                 3=not_deleted, 4=db_error
--   int32 char_id

local SM_RESTORE_CHARACTER_RESPONSE = 0x19

local RESULT_OK          = 0
local RESULT_NOT_OWNER   = 1
local RESULT_NOT_FOUND   = 2
local RESULT_NOT_DELETED = 3
local RESULT_DB_ERROR    = 4

local function send_response(gw, result, char_id)
    local buf = bytes.new()
    buf:write_byte(result)
    buf:write_int32(char_id or 0)
    player.send_packet(gw, SM_RESTORE_CHARACTER_RESPONSE, buf:to_string())
end

register_handler(0x18, function(ctx, payload)
    local char_id = payload:read_int32()
    if char_id <= 0 then
        send_response(ctx.gateway_seq_id, RESULT_NOT_FOUND, 0)
        return
    end

    -- Ownership + soft-deleted-state check via aion_getcharinfo_20160818.
    local rows, err = db.call("aion_getcharinfo_20160818", char_id)
    if err ~= nil then
        log.error("CM_RESTORE_CHARACTER: lookup err=" .. tostring(err)
            .. " char_id=" .. tostring(char_id))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, char_id)
        return
    end
    if not rows or #rows == 0 then
        send_response(ctx.gateway_seq_id, RESULT_NOT_FOUND, char_id)
        return
    end

    local info  = rows[1]
    local owner = info.account_id or info.accountid or info.account or 0
    if tonumber(owner) ~= tonumber(ctx.account_id) then
        log.warn("CM_RESTORE_CHARACTER: owner mismatch char_id=" .. tostring(char_id)
            .. " owner=" .. tostring(owner) .. " caller=" .. tostring(ctx.account_id))
        send_response(ctx.gateway_seq_id, RESULT_NOT_OWNER, char_id)
        return
    end

    -- A char with delete_date=0 is alive — restoring it is a no-op error.
    -- This guards against a malicious client that races multiple restores.
    local dd = tonumber(info.delete_date or 0) or 0
    if dd == 0 then
        send_response(ctx.gateway_seq_id, RESULT_NOT_DELETED, char_id)
        return
    end

    local _, sp_err = db.call("aion_clearchardeletetime", char_id)
    if sp_err ~= nil then
        log.error("CM_RESTORE_CHARACTER: clearchardeletetime err=" .. tostring(sp_err)
            .. " char_id=" .. tostring(char_id))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, char_id)
        return
    end

    log.info("CM_RESTORE_CHARACTER: restored char_id=" .. tostring(char_id)
        .. " account=" .. tostring(ctx.account))

    send_response(ctx.gateway_seq_id, RESULT_OK, char_id)
end)
