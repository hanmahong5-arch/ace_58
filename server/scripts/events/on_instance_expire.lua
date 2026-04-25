-- scripts/events/on_instance_expire.lua
-- Phase S-19: invoked by the asynq worker KindInstanceExpire when a scheduled
-- validity-timer fires. Delegates to the idempotent instance.on_expire which
-- rejects stale payloads (created_at_unix mismatch) arising from a server
-- restart that recycled the run_id counter.
--
-- Contract:
--   on_instance_expire(run_id, created_at_unix)

function on_instance_expire(run_id, created_at_unix)
    if not instance or not instance.on_expire then
        log.warn("on_instance_expire: instance lib not loaded")
        return
    end
    instance.on_expire(run_id, created_at_unix)
end
