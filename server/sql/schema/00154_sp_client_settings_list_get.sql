-- AionCore 5.8 — Sprint 1.1a batch 4 port: aion_ClientSettingsListGet + user_client_settings table.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClientSettingsListGet.sql
-- Original (T-SQL):
--   SELECT data_size, data
--   FROM user_client_settings
--   WHERE char_id = @char_id
--
-- Translation notes:
--   * NCSoft `user_client_settings` is a 1:1 char→blob table that stores the
--     UI layout / hotbar preferences pushed by the client every logout. The
--     blob is opaque to the server (the client serialises it and the server
--     simply stores/returns it verbatim) so we model `data` as PG `BYTEA`
--     to preserve byte-perfect round-trip without UTF-8 normalisation.
--   * `data_size` is redundant with `octet_length(data)` but the original
--     schema stored it explicitly because SQL Server's `varbinary(7168)`
--     does not expose a portable length predicate. We keep it for parity
--     with the wire payload — the 5.8 client sends it as a separate field
--     (CM_CLIENT_SETTINGS_PUT) and expects to read it back unchanged.
--   * Function declared STABLE — it never mutates state and within a single
--     transaction returns the same rows for the same input, so the planner
--     can hoist it out of joins.
--   * Table is created here (first SP in the chain to need it) using
--     IF NOT EXISTS so co-batch 00155 (Put) is safely re-runnable.
--
-- Used by:
--   scripts/handlers/cm_client_settings_load.lua  -- on enter-world hydration
--   scripts/lib/client_settings.lua               -- shared blob (de)serialiser

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_client_settings (
    char_id    INTEGER  PRIMARY KEY,
    data_size  SMALLINT NOT NULL DEFAULT 0,
    data       BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clientsettingslistget(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clientsettingslistget(_char_id INTEGER)
RETURNS TABLE (
    data_size SMALLINT,
    data      BYTEA
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ucs.data_size, ucs.data
          FROM user_client_settings ucs
         WHERE ucs.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clientsettingslistget(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_client_settings;
-- +goose StatementEnd
