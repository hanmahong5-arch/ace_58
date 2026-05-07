-- AionCore 5.8 — Sprint 1.1a batch 7 port: aion_DelMacro.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DelMacro.sql
-- Original (T-SQL):
--   DELETE user_macro WHERE char_id = @nCharId AND slot_id = @nSlotId
--
-- Translation notes:
--   * Single-row DELETE keyed on (char_id, slot_id). Returns rows-affected
--     so the caller can distinguish "slot deleted" (1) from "slot was
--     already empty" (0) — useful for the macro-save handler which sometimes
--     issues a Del for a slot the client thinks exists but the server
--     doesn't (race after a re-login before hydration completes).
--   * Table DDL co-located with 00169/00170 via IF NOT EXISTS, so this
--     migration is safely independent of run order.
--   * Function NOT declared STABLE — it mutates state.
--
-- Used by:
--   scripts/handlers/cm_macro_save.lua   -- on per-slot delete
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
DROP FUNCTION IF EXISTS aion_delmacro(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_delmacro(
    _char_id INTEGER,
    _slot_id SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM user_macro
     WHERE char_id = _char_id
       AND slot_id = _slot_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_delmacro(INTEGER, SMALLINT);
-- +goose StatementEnd
