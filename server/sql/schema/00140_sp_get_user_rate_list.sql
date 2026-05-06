-- AionCore 5.8 — Sprint 1.1a batch 1 port: aion_GetUserRateList (PvP Elo).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserRateList.sql
-- Original (T-SQL):
--   SELECT rate_id, mu, sigma, update_cnt FROM user_rate WHERE char_id = @char_id
--
-- user_rate is the per-character / per-rate-bucket TrueSkill state used by
-- arena/instance matchmaking. NCSoft hard-codes rate_id buckets in their
-- C++ engine (1=arena solo, 2=group, 3=harmony …); we mirror the schema
-- verbatim and let Lua decide which rate_id to use.
--
-- mu/sigma are TrueSkill mean/stddev as 32-bit floats (matching NCSoft's
-- `real`); update_cnt is an INT counter incremented per rate update — used
-- by anti-cheat sanity checks ("did this player just gain 50 ranks in 5
-- minutes?").
--
-- Returns 0…N rows (one per rate_id the char has ever participated in).
-- A char with no rate history → 0 rows; callers default to mu=25, sigma=8.333.

-- This migration is the first to need user_rate; create the table here.
-- IF NOT EXISTS keeps it safe to apply on partially-initialised databases.

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_rate (
    char_id     INTEGER  NOT NULL,
    rate_id     INTEGER  NOT NULL,
    mu          REAL     NOT NULL DEFAULT 25.0,
    sigma       REAL     NOT NULL DEFAULT 8.333,
    update_cnt  INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, rate_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserratelist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserratelist(_char_id INTEGER)
RETURNS TABLE (
    rate_id    INTEGER,
    mu         REAL,
    sigma      REAL,
    update_cnt INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ur.rate_id, ur.mu, ur.sigma, ur.update_cnt
          FROM user_rate ur
         WHERE ur.char_id = _char_id
         ORDER BY ur.rate_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserratelist(INTEGER);
DROP TABLE  IF EXISTS user_rate;
-- +goose StatementEnd
