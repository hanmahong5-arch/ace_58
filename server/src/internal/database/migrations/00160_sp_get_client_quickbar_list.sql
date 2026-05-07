-- AionCore 5.8 — Sprint 1.1a batch 5 port: aion_GetClientQuickBarList (login hotbar hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetClientQuickBarList.sql
-- Original (T-SQL):
--   SELECT data_size, data
--   FROM user_client_quickbar
--   WHERE char_id = @char_id
--
-- Translation notes:
--   * NCSoft `user_client_quickbar` is a 1:1 char→blob table for the slotted
--     hotbar config (skill/item bindings on the client's bottom bar). The
--     blob is opaque server-side — same contract as user_client_settings
--     (00154) — so we model `data` as PG `BYTEA` for byte-perfect round-trip.
--   * `data_size` is redundant with octet_length(data) but kept for wire
--     parity (CM_QUICKBAR_SET sends it as a separate field; client reads
--     back unchanged).
--   * SQL Server `varbinary(8000)` (or similar) → PG BYTEA is unbounded;
--     enforce length at the application boundary, not in the column type.
--   * Function declared STABLE — pure read.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- hotbar hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_client_quickbar (
    char_id   INTEGER  PRIMARY KEY,
    data_size SMALLINT NOT NULL DEFAULT 0,
    data      BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getclientquickbarlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getclientquickbarlist(_char_id INTEGER)
RETURNS TABLE (
    data_size SMALLINT,
    data      BYTEA
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uq.data_size, uq.data
          FROM user_client_quickbar uq
         WHERE uq.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getclientquickbarlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_client_quickbar;
-- +goose StatementEnd
