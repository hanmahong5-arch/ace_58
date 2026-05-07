-- AionCore 5.8 — Sprint 1.1a batch 7 port: aion_SetMacro (upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetMacro.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_macro(UPDLOCK)
--               WHERE char_id = @nCharId AND slot_id = @nSlotId)
--     UPDATE user_macro SET data = @sData
--      WHERE char_id = @nCharId AND slot_id = @nSlotId
--   ELSE
--     INSERT user_macro(char_id, slot_id, data)
--          VALUES (@nCharId, @nSlotId, @sData)
--
-- Translation notes:
--   * Same canonical SQL Server 2000 upsert pattern as 00155
--     (aion_ClientSettingsPut). PG `INSERT ... ON CONFLICT DO UPDATE`
--     is genuinely atomic (no UPDLOCK race window between SELECT and the
--     INSERT branch) — two concurrent puts on the same (char_id, slot_id)
--     are serialised at the index level, last-writer-wins.
--   * Composite key (char_id, slot_id) instead of just char_id — a single
--     char owns multiple slots, so upsert keys on both columns. Table DDL
--     is co-located with 00169 (GetMacro) via IF NOT EXISTS, making this
--     migration order-independent.
--   * The blob (`@sData` NVARCHAR(1024) → BYTEA) is passed through; see
--     00169 for why we widened to BYTEA (NCSoft macro payload is binary
--     client serialisation, not text).
--   * Returns rows-affected (always 1 for a successful upsert) so the
--     caller can sanity-check the round-trip — matches 00155 / 00144 /
--     00134 convention.
--
-- Used by:
--   scripts/handlers/cm_macro_save.lua   -- on per-slot save
--   scripts/lib/macro.lua

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
DROP FUNCTION IF EXISTS aion_setmacro(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmacro(
    _char_id INTEGER,
    _slot_id SMALLINT,
    _data    BYTEA
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    INSERT INTO user_macro(char_id, slot_id, data)
    VALUES (_char_id, _slot_id, _data)
    ON CONFLICT (char_id, slot_id) DO UPDATE
       SET data = EXCLUDED.data;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmacro(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd
