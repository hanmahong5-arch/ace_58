-- AionCore 5.8 — Sprint 1.1a batch 5 port: aion_GetClientFavoriteList (login favorites hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetClientFavoriteList.sql
-- Original (T-SQL):
--   SELECT data_size, data
--   FROM user_client_Favorite
--   WHERE char_id = @char_id
--
-- Translation notes:
--   * NCSoft case-mixed table name `user_client_Favorite` — PG folds
--     unquoted identifiers to lowercase, so the PG table is plain
--     `user_client_favorite`. The handler/Lua layer never sees the raw
--     name, so the case difference is invisible to callers.
--   * Same blob contract as user_client_settings (00154) and quickbar
--     (00160) — opaque BYTEA round-trip; data_size kept for wire parity.
--   * Favorites blob holds the player's pinned NPC / quest / location
--     bookmarks shown in the in-game compass UI (CM_QUEST_FAVORITE_*).
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- favorite-list hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_client_favorite (
    char_id   INTEGER  PRIMARY KEY,
    data_size SMALLINT NOT NULL DEFAULT 0,
    data      BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getclientfavoritelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getclientfavoritelist(_char_id INTEGER)
RETURNS TABLE (
    data_size SMALLINT,
    data      BYTEA
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uf.data_size, uf.data
          FROM user_client_favorite uf
         WHERE uf.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getclientfavoritelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_client_favorite;
-- +goose StatementEnd
