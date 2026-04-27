-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetInstanceAchievementList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInstanceAchievementList.sql
-- Loads every per-character per-(world,page,version) achievement-progress blob.
-- Called on character login.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceachievementlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstanceachievementlist(_char_id INTEGER)
RETURNS TABLE (
    out_world_id   INTEGER,
    out_spawn_page INTEGER,
    out_version    INTEGER,
    out_data       BYTEA
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT uia.world_id, uia.spawn_page, uia.version, uia.data
      FROM user_instance_achievement uia
     WHERE uia.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceachievementlist(INTEGER);
-- +goose StatementEnd
