-- scripts/handlers/cm_dialog_request.lua
-- CM_DIALOG_REQUEST (0x6A): client interacted with an NPC.
--
-- Payload (LE, unverified):
--   int32  npc_entity_id
--
-- Dispatches to the dialog handler registered for the NPC's template ID.

register_handler(0x6A, function(ctx, payload)
    if not dialog then
        log.warn("CM_DIALOG_REQUEST: dialog library not loaded")
        return
    end

    local npc_eid = payload:read_int32()
    if npc_eid == 0 then
        return
    end

    -- Refuse if the player is dead (prevents interaction during death screen).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    -- Range gate: player must be within 15m of the NPC.
    local ppos = entity.get_position(ctx.entity_id)
    local npos = entity.get_position(npc_eid)
    if ppos and npos then
        local dx = (ppos.x or 0) - (npos.x or 0)
        local dy = (ppos.y or 0) - (npos.y or 0)
        local dz = (ppos.z or 0) - (npos.z or 0)
        if dx * dx + dy * dy + dz * dz > 225.0 then  -- 15m squared
            return
        end
    end

    if not dialog.open(ctx, npc_eid) then
        log.info("CM_DIALOG_REQUEST: no dialog for npc_eid=" .. tostring(npc_eid))
    end
end)
