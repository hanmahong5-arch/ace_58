-- scripts/handlers/cm_delete_character.lua
-- CM_DELETE_CHARACTER (0x14): client requests soft-deletion of a character.
--
-- AION 5.8 uses a 7-day grace window. The SP aion_setchardeletetime writes
-- an absolute Unix timestamp into user_data.delete_date; the character stays
-- in user_data (and remains listed with a greyed-out countdown) until a
-- nightly sweeper calls aion_deletechar on expiry. If the player changes
-- their mind they call CM_RESTORE_CHARACTER (future opcode) which maps to
-- aion_clearchardeletetime.
--
-- Payload (5.8 client, LE):
--   int32 char_id              -- target character
--   int32 confirm              -- magic token == 0xDEADBEEF; prevents mis-clicks
--
-- Response: SM_DELETE_CHARACTER_RESPONSE (0x17):
--   byte  result               -- 0=OK, 1=not_owner, 2=not_found, 3=bad_confirm,
--                                 4=db_error
--   int32 char_id
--   int32 delete_unixtime      -- when the character will actually be purged
--                                 (0 on error)

local GRACE_WINDOW_SECONDS = 7 * 24 * 3600   -- 7-day AION delete grace
local CONFIRM_TOKEN        = 0xDEADBEEF       -- client constant; guards mis-clicks

local RESULT_OK          = 0
local RESULT_NOT_OWNER   = 1
local RESULT_NOT_FOUND   = 2
local RESULT_BAD_CONFIRM = 3
local RESULT_DB_ERROR    = 4

local function send_response(gw, result, char_id, when)
    local buf = bytes.new()
    buf:write_byte(result)
    buf:write_int32(char_id or 0)
    buf:write_int32(when or 0)
    player.send_packet(gw, 0x17, buf:to_string())
end

-- now_unix returns the current wall-clock Unix timestamp as an integer.
-- os.time is available from the sandboxed `os` lib (openSafeLibs). In tests
-- the Lua state is deterministic but os.time() still advances normally.
local function now_unix()
    if os and os.time then return os.time() end
    return 0
end

register_handler(0x14, function(ctx, payload)
    local char_id = payload:read_int32()
    -- read_int32 returns signed int32 so 0xDEADBEEF is surfaced as a negative
    -- number. Compare against the signed bit-pattern to avoid a silent miss.
    local confirm = payload:read_int32()

    if char_id <= 0 then
        send_response(ctx.gateway_seq_id, RESULT_NOT_FOUND, 0, 0)
        return
    end

    -- 32-bit two's-complement of 0xDEADBEEF is -559038737. Accept either form
    -- so callers (tests, potential client patches) can pass either value.
    if confirm ~= CONFIRM_TOKEN and confirm ~= -559038737 then
        send_response(ctx.gateway_seq_id, RESULT_BAD_CONFIRM, char_id, 0)
        return
    end

    -- Verify the char belongs to this account. aion_getcharinfo_20160818
    -- is used at enter-world and returns account_id / world / etc. Reusing
    -- it here avoids introducing an extra SP just for the ownership check.
    local rows, err = db.call("aion_getcharinfo_20160818", char_id)
    if err ~= nil then
        log.error("CM_DELETE_CHARACTER: lookup err=" .. tostring(err)
            .. " char_id=" .. tostring(char_id))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, char_id, 0)
        return
    end
    if not rows or #rows == 0 then
        send_response(ctx.gateway_seq_id, RESULT_NOT_FOUND, char_id, 0)
        return
    end

    local info = rows[1]
    -- NCSoft exports use several column name variants across migrations.
    local owner = info.account_id or info.accountid or info.account or 0
    if tonumber(owner) ~= tonumber(ctx.account_id) then
        log.warn("CM_DELETE_CHARACTER: owner mismatch char_id=" .. tostring(char_id)
            .. " owner=" .. tostring(owner) .. " caller=" .. tostring(ctx.account_id))
        send_response(ctx.gateway_seq_id, RESULT_NOT_OWNER, char_id, 0)
        return
    end

    -- Soft-delete: schedule purge at now + 7 days. The sweeper job dispatches
    -- aion_deletechar when the absolute timestamp is reached.
    local delete_at = now_unix() + GRACE_WINDOW_SECONDS
    local _, sp_err = db.call("aion_setchardeletetime", char_id, delete_at)
    if sp_err ~= nil then
        log.error("CM_DELETE_CHARACTER: setchardeletetime err=" .. tostring(sp_err)
            .. " char_id=" .. tostring(char_id))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, char_id, 0)
        return
    end

    log.info("CM_DELETE_CHARACTER: scheduled purge char_id=" .. tostring(char_id)
        .. " account=" .. tostring(ctx.account) .. " at=" .. tostring(delete_at))

    send_response(ctx.gateway_seq_id, RESULT_OK, char_id, delete_at)
end)
