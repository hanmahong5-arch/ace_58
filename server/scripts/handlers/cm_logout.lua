-- scripts/handlers/cm_logout.lua
-- CM_LOGOUT (0xAB): client requests graceful character logout.
--
-- Payload: empty (no fields).
--
-- On receipt:
--   1. Persist final HP/MP/FP + position back to the database via aion_SaveCharInfo.
--   2. Clear the dead flag so the character does not log back in as dead.
--   3. No SM reply is sent — the gateway closes the session after this handler returns.
--
-- NOTE: aion_SaveCharInfo SP name and param order are unverified; adjust after
-- confirming the stored procedure signature in aion_world_live.

register_handler(0xAB, function(ctx, payload)
    local eid    = ctx.entity_id
    local char_id = entity.get_stat(eid, "char_id")

    if char_id <= 0 then
        log.warn("CM_LOGOUT: entity=" .. tostring(eid) .. " has no char_id, skipping save")
        return
    end

    -- Read current world state from ECS.
    local pos = entity.get_position(eid)
    local x       = pos.x       or 0
    local y       = pos.y       or 0
    local z       = pos.z       or 0
    local heading = pos.heading or 0

    local hp  = entity.get_stat(eid, "hp")
    local mp  = entity.get_stat(eid, "mp")
    local fp  = entity.get_stat(eid, "fp")

    -- Ensure the character saves as alive regardless of field value.
    -- (Client-side death is transient; bind-point revive will restore stats.)
    entity.set_stat(eid, "dead", 0)

    -- Persist via stored procedure.
    -- SP expected signature: aion_SaveCharInfo(char_id, x, y, z, dir, now_hit, now_mana, now_flight)
    local _, save_err = db.call(
        "aion_SaveCharInfo",
        char_id,
        math.floor(x),
        math.floor(y),
        math.floor(z),
        math.floor(heading),
        math.max(1, math.floor(hp)),   -- never save 0 HP
        math.floor(mp),
        math.floor(fp)
    )

    if save_err then
        log.warn("CM_LOGOUT: save failed char_id=" .. tostring(char_id)
            .. " err=" .. tostring(save_err))
    else
        log.info("CM_LOGOUT: saved char_id=" .. tostring(char_id)
            .. " pos=(" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. ")"
            .. " hp=" .. tostring(hp) .. " mp=" .. tostring(mp) .. " fp=" .. tostring(fp))
    end

    -- Gateway closes the TCP session after the handler returns; no SM needed.
end)
