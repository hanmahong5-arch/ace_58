-- AionCore 5.8 — Sprint 1.1a batch 6 port: aion_GetBookmarkList (login bookmark hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetBookmarkList.sql
-- Original (T-SQL):
--   SELECT bookmark, world, x, y, z FROM bookmark WHERE char_id = @nCharId
--
-- Translation notes:
--   * NCSoft `bookmark` is the lowest-cardinality table touched by enter_world.
--     Each row is one teleport-favorite the player saved via the world map UI:
--       - bookmark   SMALLINT : slot index (0..N), unique within char_id
--       - world      INTEGER  : world id (zone)
--       - x,y,z      REAL     : world-space position
--   * No filter beyond char_id — soft-delete is "row missing", not a tombstone.
--   * Returned in PRIMARY-KEY order (char_id, bookmark) for deterministic
--     wire output; NCSoft relies on engine row order, but PG without ORDER BY
--     is undefined — be explicit.
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- bookmark hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS bookmark (
    char_id  INTEGER  NOT NULL,
    bookmark SMALLINT NOT NULL,
    world    INTEGER  NOT NULL DEFAULT 0,
    x        REAL     NOT NULL DEFAULT 0,
    y        REAL     NOT NULL DEFAULT 0,
    z        REAL     NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, bookmark)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_bookmark_char ON bookmark(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbookmarklist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbookmarklist(_char_id INTEGER)
RETURNS TABLE (
    bookmark SMALLINT,
    world    INTEGER,
    x        REAL,
    y        REAL,
    z        REAL
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT b.bookmark, b.world, b.x, b.y, b.z
          FROM bookmark b
         WHERE b.char_id = _char_id
         ORDER BY b.bookmark ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbookmarklist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_bookmark_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS bookmark;
-- +goose StatementEnd
