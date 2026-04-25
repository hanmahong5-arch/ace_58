-- scripts/events/on_daily_reset.lua
-- Phase S-19: invoked by asynq KindDailyReset on the scheduled daily cron.
-- The primary job is to purge stale user_instance cooldown rows via the SP
-- aion_initinstancecooltime_170817 (which deletes rows whose reentrance_time
-- has already elapsed). Future phases hang additional once-a-day chores
-- (bonus gift reset, login streak tick, world-boss spawn schedule kick) off
-- the same function.
--
-- Contract:
--   on_daily_reset()
-- Arguments: none (Go passes no parameters for this kind).

function on_daily_reset()
    if not db then
        log.warn("on_daily_reset: db unavailable, skipping")
        return
    end
    local _, err = db.call("aion_initinstancecooltime_170817")
    if err then
        log.warn("on_daily_reset: aion_initinstancecooltime_170817 err=" .. tostring(err))
        return
    end
    log.info("on_daily_reset: instance cooltime swept")
end
