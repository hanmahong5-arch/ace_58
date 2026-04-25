-- scripts/handlers/cm_instance_leave.lua
-- CM_INSTANCE_LEAVE (0xD1): caller requests to leave the current instance.
--
-- Payload: empty.
-- Response: a SM_INSTANCE_MEMBER_LEAVE broadcast is emitted by instance.leave
--   to remaining members; the caller is teleported to bind via the SP path.
--
-- Leaving does NOT dispose the run (see plan §Lifecycle.Leave) — the player
-- can rejoin via CM_INSTANCE_ENTER for the same template while the run is
-- still active; the cooldown was burned at original entry.

register_handler(0xD1, function(ctx, _payload)
    local ok, reason = instance.leave(ctx.entity_id)
    if not ok then
        log.info("CM_INSTANCE_LEAVE: noop reason=" .. tostring(reason))
    end
end)
