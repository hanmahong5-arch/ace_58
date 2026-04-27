-- scripts/handlers/cm_logout.lua
-- CM_LOGOUT (0xAB): client requests graceful character logout.
--
-- Payload: empty (no fields).
--
-- On receipt:
--   1. Clear the dead flag so the character does not log back in as dead.
--   2. Persist final position via aion_setcharlocation (cur_server/world/xyz).
--   3. Stamp last_logout_time + bump playtime via
--      aion_setcharlogouttime_20120516 (this SP also computes the elapsed
--      session minutes and accumulates them onto user_data.playtime).
--   4. No SM reply — the gateway closes the session after this handler returns.
--
-- Round 10 fix: the previous version called a fictional aion_SaveCharInfo
-- SP, so logout state was silently dropped. We now use the real two-call
-- sequence the NCSoft server uses (location + logout-time).

register_handler(0xAB, function(ctx, payload)
    local eid     = ctx.entity_id
    local char_id = entity.get_stat(eid, "char_id")

    if not char_id or char_id <= 0 then
        log.warn("CM_LOGOUT: entity=" .. tostring(eid) .. " has no char_id, skipping save")
        return
    end

    -- Read current world state from ECS.
    local pos = entity.get_position(eid) or {}
    local x         = pos.x        or 0
    local y         = pos.y        or 0
    local z         = pos.z        or 0
    local world_id  = entity.get_stat(eid, "world_id") or 0
    local cur_server = entity.get_stat(eid, "cur_server") or 0

    -- Ensure the character saves as alive regardless of field value.
    -- (Client-side death is transient; bind-point revive will restore stats.)
    entity.set_stat(eid, "dead", 0)

    -- 1) Persist the location row (cur_server/world/xyz).
    local _, loc_err = db.call(
        "aion_setcharlocation",
        char_id,
        cur_server,
        world_id,
        x, y, z
    )
    if loc_err then
        log.warn("CM_LOGOUT: setcharlocation err=" .. tostring(loc_err)
            .. " char_id=" .. tostring(char_id))
    end

    -- 2) Stamp logout time + accumulate playtime.
    local _, lo_err = db.call("aion_setcharlogouttime_20120516", char_id)
    if lo_err then
        log.warn("CM_LOGOUT: setcharlogouttime err=" .. tostring(lo_err)
            .. " char_id=" .. tostring(char_id))
    else
        log.info("CM_LOGOUT: persisted char_id=" .. tostring(char_id)
            .. " pos=(" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. ")"
            .. " world=" .. tostring(world_id))
    end

    -- Gateway closes the TCP session after the handler returns; no SM needed.
end)
