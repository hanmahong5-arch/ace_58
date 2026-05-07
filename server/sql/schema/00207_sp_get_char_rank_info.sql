-- AionCore 5.8 — Sprint 1.1a batch 14 port: aion_GetCharRankInfo (per-char per-rank profile read).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCharRankInfo.sql
-- Original (T-SQL):
--   select global_ranking, point, last_ranking, last_point, best_ranking, best_point
--   from   user_rank
--   where  char_id = @char_id and rank_id = @rank_id
--
-- Translation notes:
--   * Read-only SP returning at most one row (the (char_id, rank_id) tuple
--     is the natural key — composite PK on the new table).
--   * Six columns, all integer-shaped:
--       global_ranking — current global rank (1 = best)
--       point          — current point total
--       last_ranking   — previous-cycle rank (snapshot)
--       last_point     — previous-cycle points (snapshot)
--       best_ranking   — all-time best rank (lower = better)
--       best_point     — all-time best points
--   * NCSoft uses INT for rank columns; we mirror that. point columns are
--     also INT in NCSoft but BIGINT is more forward-safe for the entropy
--     roadmap (Q2+ can mint multi-million point pools). We pin INT for
--     byte-equal NCSoft compat; future migration may widen.
--
-- Bug-for-bug:
--   * Missing (char_id, rank_id) tuple → 0 rows. NCSoft does not surface a
--     "not-found" error code; absence is the indicator. Caller (Lua handler)
--     treats 0 rows as "rank profile uninitialised".
--
-- Used by:
--   scripts/handlers/cm_rank_query.lua  (Q3 — abyss/PvP rank UI)
--   scripts/lib/char_rank.lua

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_rank (
    char_id        INTEGER NOT NULL,
    rank_id        INTEGER NOT NULL,
    global_ranking INTEGER NOT NULL DEFAULT 0,
    point          INTEGER NOT NULL DEFAULT 0,
    last_ranking   INTEGER NOT NULL DEFAULT 0,
    last_point     INTEGER NOT NULL DEFAULT 0,
    best_ranking   INTEGER NOT NULL DEFAULT 0,
    best_point     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, rank_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharrankinfo(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharrankinfo(
    _char_id  INTEGER,
    _rank_id  INTEGER
) RETURNS TABLE (
    global_ranking INTEGER,
    point          INTEGER,
    last_ranking   INTEGER,
    last_point     INTEGER,
    best_ranking   INTEGER,
    best_point     INTEGER
)
LANGUAGE SQL STABLE AS $$
    SELECT global_ranking, point, last_ranking, last_point, best_ranking, best_point
      FROM user_rank
     WHERE char_id = _char_id
       AND rank_id = _rank_id;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharrankinfo(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_rank;
-- +goose StatementEnd
