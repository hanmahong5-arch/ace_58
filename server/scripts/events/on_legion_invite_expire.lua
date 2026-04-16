-- scripts/events/on_legion_invite_expire.lua
-- Phase S-17: called by the river LegionInviteExpireWorker via LuaInvoker.
--
-- Contract:
--   on_legion_invite_expire(legion_id:int64, inviter_eid:int64, target_eid:int64)
--
-- Clears the pending invite entry if it still matches the call args. The
-- replacement for the S-10 tick counter is gated on the jobq facade being
-- wired; when jobq is nil, legion.lua still falls back to on_tick based
-- expiry and this handler is a no-op.

function on_legion_invite_expire(legion_id, inviter_eid, target_eid)
    log.info("on_legion_invite_expire: legion=" .. tostring(legion_id)
        .. " inviter=" .. tostring(inviter_eid)
        .. " target=" .. tostring(target_eid))

    if legion and legion._clear_invite then
        legion._clear_invite(target_eid, legion_id)
    end
end
