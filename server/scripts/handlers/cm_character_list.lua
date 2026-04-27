-- scripts/handlers/cm_character_list.lua
-- CM_CHARACTER_LIST (0x11): client requests a character list refresh.
--
-- AION 5.8 sends this after the player clicks "Back" from character select,
-- or after deleting/restoring a character. The server replies with
-- SM_CHARACTER_LIST (0x10) — a (count, [char_id, name, …]) tuple — using
-- the result of the aion_getcharidlist SP.
--
-- The full per-character payload is built lazily by the gateway on enter-
-- world (CM_ENTER_WORLD calls aion_GetCharInfo_20160818 for the picked id);
-- this handler only needs the lightweight (id, name) pairs so the client
-- can render the selection screen.

local SM_CHARACTER_LIST = 0x10

local function send_list(gw, entries)
    local buf = bytes.new()
    buf:write_int32(#entries)
    for _, e in ipairs(entries) do
        buf:write_int32(e.char_id or 0)
        buf:write_string_utf16(e.user_id or "")
    end
    player.send_packet(gw, SM_CHARACTER_LIST, buf:to_string())
end

register_handler(0x11, function(ctx, payload)
    -- The wire payload is a 0-byte stub on the live client; ignore.
    log.info("CM_CHARACTER_LIST refresh requested by " .. tostring(ctx.account)
        .. " account_id=" .. tostring(ctx.account_id))

    if not ctx.account_id or ctx.account_id <= 0 then
        log.warn("CM_CHARACTER_LIST: missing account_id; sending empty list")
        send_list(ctx.gateway_seq_id, {})
        return
    end

    local rows, err = db.call("aion_getcharidlist", ctx.account_id)
    if err ~= nil then
        log.error("CM_CHARACTER_LIST: aion_getcharidlist err=" .. tostring(err)
            .. " account_id=" .. tostring(ctx.account_id))
        send_list(ctx.gateway_seq_id, {})
        return
    end

    -- aion_getcharidlist returns rows as { {char_id=..., user_id=...}, ... }.
    -- The SP already filters out finally-deleted chars (delete_complete_date>0)
    -- and chars whose 7-day grace has expired but not yet been swept.
    local entries = {}
    if rows then
        for i, r in ipairs(rows) do
            entries[i] = {
                char_id = r.char_id or r[1] or 0,
                user_id = r.user_id or r[2] or "",
            }
        end
    end

    log.info("CM_CHARACTER_LIST: sent " .. tostring(#entries) .. " chars to "
        .. tostring(ctx.account))
    send_list(ctx.gateway_seq_id, entries)
end)
