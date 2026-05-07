-- AionCore 5.8 — Sprint 1.1a batch 7 port: aion_GetMacro + user_macro table.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetMacro.sql
-- Original (T-SQL):
--   SELECT slot_id, data FROM user_macro WHERE char_id = @nCharId
--
-- Translation notes:
--   * NCSoft `user_macro` is a 0..N char→macro-slot table; players define
--     up to ~12 macro slots (chat / skill / emote chains) and the client
--     hydrates all of them on enter-world. Each row is one slot (slot_id,
--     opaque data blob).
--   * The dump declared `@sData NVARCHAR(1024)` on the SetMacro side, but
--     the macro payload is client-serialised binary (concatenated commands +
--     icon refs + names) — NCSoft historically widened it to varbinary in
--     later patches. We model `data` as PG `BYTEA` to preserve byte-perfect
--     round-trip without UTF-16 normalisation, mirroring 00154
--     (user_client_settings.data) which faces the same situation.
--   * The commented `@nSlotId` branch in the original is dead code; we keep
--     only the active "all slots" path because cm_macro_load.lua issues a
--     bulk hydrate and the client filters per-slot updates via Set/Del.
--   * `slot_id` in the dump was TINYINT — PG SMALLINT is the canonical
--     equivalent (PG has no TINYINT). Range 0..255 fits, NCSoft real values
--     are 0..11.
--   * PRIMARY KEY (char_id, slot_id) — a slot is unique per char.
--   * Function declared STABLE.
--   * Table is created here (first SP in the macro chain) using IF NOT
--     EXISTS so co-batch 00170/00171 are safely re-runnable in any order.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- macro hydration on login
--   scripts/lib/macro.lua                -- shared (de)serialiser

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_macro (
    char_id INTEGER  NOT NULL,
    slot_id SMALLINT NOT NULL,
    data    BYTEA    NOT NULL DEFAULT '\x'::BYTEA,
    PRIMARY KEY (char_id, slot_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_macro_char ON user_macro(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmacro(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmacro(_char_id INTEGER)
RETURNS TABLE (
    slot_id SMALLINT,
    data    BYTEA
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT um.slot_id, um.data
          FROM user_macro um
         WHERE um.char_id = _char_id
         ORDER BY um.slot_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmacro(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_macro_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_macro;
-- +goose StatementEnd
