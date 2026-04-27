-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetInstanceAchievement.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInstanceAchievement.sql
-- Upsert per (char_id, world_id, spawn_page, version) → data blob.
-- T-SQL varbinary(100) → BYTEA. T-SQL IF EXISTS+UPDATE/ELSE INSERT → ON CONFLICT.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceachievement(INTEGER, INTEGER, INTEGER, INTEGER, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstanceachievement(
    _char_id    INTEGER,
    _world_id   INTEGER,
    _spawn_page INTEGER,
    _version    INTEGER,
    _data       BYTEA
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_instance_achievement (char_id, world_id, spawn_page, version, data)
    VALUES (_char_id, _world_id, _spawn_page, _version, _data)
    ON CONFLICT (char_id, world_id, spawn_page, version) DO UPDATE
       SET data = EXCLUDED.data;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceachievement(INTEGER, INTEGER, INTEGER, INTEGER, BYTEA);
-- +goose StatementEnd
