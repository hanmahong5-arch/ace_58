-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_InitInstanceCooltime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_InitInstanceCooltime.sql
-- Original (non-suffixed) sibling of InitInstanceCooltime_170817 (00027).
-- Behaviour is byte-identical: delete user_instance rows whose reentrance_time
-- is > 8h old. Kept for back-compat with older callers that reference the
-- shorter name (e.g. boot scripts, GM tools).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_initinstancecooltime();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_initinstancecooltime()
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
DROP FUNCTION IF EXISTS aion_initinstancecooltime();
-- +goose StatementEnd
