-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_InitInstanceCooltime_170817.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_InitInstanceCooltime_170817.sql
-- Daily-reset cleanup: removes instance entries whose reentrance_time is
-- older than now - 8h. Called by the scheduler daemon (cron-like job).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_initinstancecooltime_170817();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_initinstancecooltime_170817()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_instance
     WHERE reentrance_time
         < (GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0) - 8 * 3600);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_initinstancecooltime_170817();
-- +goose StatementEnd
