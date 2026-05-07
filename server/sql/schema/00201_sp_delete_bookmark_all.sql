-- AionCore 5.8 — Sprint 1.1a batch 13 port: aion_DeleteBookmarkAll (per-char bookmark wipe).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteBookmarkAll.sql
-- Original (T-SQL):
--   DELETE bookmark WHERE char_id = @nCharId
--
-- Translation notes:
--   * Pure per-char wipe of every bookmark row the player owns. Used in two
--     places NCSoft documents:
--       a) /bookmark clearall  — explicit user gesture
--       b) char-delete cascade — when DeleteChar runs, this is called as part
--          of the cleanup chain (mirrored in 00131-ish family for full delete).
--   * NO existence guard, NO error on empty result. char_id with zero rows
--     returns rowsaffected=0 silently — same as T-SQL. This is the operational
--     contract clear-on-empty.
--   * Returns rows-affected so callers can log "X bookmarks wiped" or detect
--     the missing-char case. NCSoft itself ignores the return value but the
--     metric is too cheap to drop.
--
-- Used by:
--   scripts/handlers/cm_bookmark_clear.lua    -- on /bookmark clearall
--   scripts/lib/char_delete.lua               -- char delete cascade

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletebookmarkall(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletebookmarkall(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM bookmark WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletebookmarkall(INTEGER);
-- +goose StatementEnd
