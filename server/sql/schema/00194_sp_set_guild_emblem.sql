-- AionCore 5.8 — Sprint 1.1a batch 12 port: aion_SetGuildEmblem.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildEmblem.sql
-- Original (T-SQL):
--   UPDATE guild
--      SET emblem_img_version=@nVersion, emblem_img_last_version=@nLastVersion,
--          emblem_bgcolor=@nBgColor, emblem_img=@byEmblem
--    WHERE id = @nGuildId
--
-- Translation notes:
--   * `emblem_img` is a binary blob (T-SQL `Image` type, basically BYTEA in
--     PG). NCSoft writes the raw uncompressed legion-emblem texture here —
--     the client uploads it on /legion emblem-set and the server distributes
--     it back to anyone in render distance via a streaming RPC.
--   * `emblem_img_version` already exists from 00052 (round4 scaffold).
--     `emblem_img_last_version` and `emblem_img` are added here as the first
--     consumers in the SP catalogue; the GET path (aion_GetGuildEmblem,
--     not yet ported) will read all four together.
--   * `emblem_bgcolor` also pre-exists from 00052.
--   * NO existence guard on _guild_id in T-SQL: a SetEmblem on a deleted
--     guild silently no-ops (UPDATE 0 rows). Bug-for-bug — caller is
--     responsible for legion liveness.
--   * Returns rows-affected (0 = no such guild, 1 = updated).
--
-- Used by:
--   scripts/handlers/cm_legion_emblem_set.lua  -- on emblem upload
--   scripts/lib/guild.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- guild — extend with emblem_img_last_version + emblem_img blob.
-- (emblem_img_version + emblem_bgcolor pre-exist from 00052_round4.)
-- ====================================================================
ALTER TABLE guild
    ADD COLUMN IF NOT EXISTS emblem_img_last_version SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS emblem_img              BYTEA;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildemblem(INTEGER, SMALLINT, SMALLINT, INTEGER, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildemblem(
    _guild_id          INTEGER,
    _version           SMALLINT,
    _last_version      SMALLINT,
    _bg_color          INTEGER,
    _emblem            BYTEA
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE guild
       SET emblem_img_version      = _version,
           emblem_img_last_version = _last_version,
           emblem_bgcolor          = _bg_color,
           emblem_img              = _emblem
     WHERE id = _guild_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildemblem(INTEGER, SMALLINT, SMALLINT, INTEGER, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE guild
    DROP COLUMN IF EXISTS emblem_img,
    DROP COLUMN IF EXISTS emblem_img_last_version;
-- +goose StatementEnd
