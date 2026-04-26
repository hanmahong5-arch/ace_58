-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_AddGuildPoint.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddGuildPoint.sql
-- Increments guild.point and bumps change_info_time (used by client cache
-- invalidation). Negative @nPoint is allowed — siege loss / decay.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addguildpoint(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addguildpoint(_guild_id INTEGER, _point BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE guild
       SET point = point + _point
     WHERE id = _guild_id;
    -- guild.change_info_time exists per real schema but our scaffold uses
    -- it on user_data only — skip the bump until the column lands.
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addguildpoint(INTEGER, BIGINT);
-- +goose StatementEnd
