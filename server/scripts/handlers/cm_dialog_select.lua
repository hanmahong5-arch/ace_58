-- scripts/handlers/cm_dialog_select.lua
-- CM_DIALOG_SELECT (0x6B): player picked an option from an open dialog.
--
-- Payload (LE, unverified):
--   int32  npc_entity_id
--   int32  option_id      -- value from dialog.send_window options[i].id

register_handler(0x6B, function(ctx, payload)
    if not dialog then
        log.warn("CM_DIALOG_SELECT: dialog library not loaded")
        return
    end

    local npc_eid   = payload:read_int32()
    local option_id = payload:read_int32()

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    if not dialog.select(ctx, npc_eid, option_id) then
        log.info("CM_DIALOG_SELECT: no dialog handler for npc_eid="
            .. tostring(npc_eid) .. " opt=" .. tostring(option_id))
    end
end)
