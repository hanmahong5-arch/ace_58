-- AionCore 5.8 — Sprint 1.1a batch 16 port: aion_GetReformCount (reform-count SELECT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetReformCount.sql
-- Original (T-SQL):
--   SELECT next_reset_time, reform_count
--   FROM user_reform
--   WHERE char_id = @char_id
--
-- Schema delta:
--   First port to touch user_reform — table does not yet exist in PG.
--   The reform feature (装备改造 / re-roll item options) tracks per-char
--   weekly reset state: how many reforms used this cycle (reform_count)
--   and when the cycle resets (next_reset_time, epoch seconds).
--
-- Translation notes:
--   * NCSoft column types (verified against schema dump):
--       char_id          INT  (PK; one row per char)
--       next_reset_time  INT  (epoch seconds — overflows 2038, NCSoft bug
--                              never fixed, pinned verbatim)
--       reform_count     INT  (cumulative count; reset to 0 on next_reset
--                              boundary by gameplay layer, not server SP)
--   * Single-row SP — `WHERE char_id=@char_id` on PK; either zero or one row.
--   * STABLE marker — pure SELECT, planner-inlinable.
--   * Sister 00218 SetReformCount creates the row on first write
--     (UPDATE … IF @@ROWCOUNT=0 INSERT). Get returns empty result for
--     a char that has never reformed.
--
-- Bug-for-bug:
--   * `next_reset_time INT` overflows at 2038-01-19 03:14:07 UTC. NCSoft
--     never fixed; we pin INTEGER for byte-for-byte parity with on-the-wire
--     payload. Operationally, the reset cycle is weekly, so any cycle
--     that crosses 2038 will compute a wrap-around timestamp — gameplay
--     layer must clamp / detect.
--   * No char_id link to user_data — orphan-tolerant (same precedent as
--     item_seal / wardrobe). Reform state can outlive the parent char.
--
-- Used by:
--   scripts/handlers/cm_item_reform_open.lua  (UI opens reform window)
--   scripts/lib/reform.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_reform — first introduction. PK on char_id (one row per char).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_reform (
    char_id          INTEGER PRIMARY KEY,
    next_reset_time  INTEGER NOT NULL DEFAULT 0,
    reform_count     INTEGER NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getreformcount(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getreformcount(_char_id INTEGER)
RETURNS TABLE (
    next_reset_time INTEGER,
    reform_count    INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT r.next_reset_time, r.reform_count
          FROM user_reform r
         WHERE r.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getreformcount(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_reform;
-- +goose StatementEnd
