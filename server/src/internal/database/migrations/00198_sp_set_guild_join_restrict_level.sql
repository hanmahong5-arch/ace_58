-- AionCore 5.8 — Sprint 1.1a batch 12 port: aion_SetGuildJoinRestrictLevel.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildJoinRestrictLevel.sql
-- Original (T-SQL):
--   UPDATE guild SET join_restrict_level = @nJoinRestrictLevel WHERE id = @nGuildId
--
-- Translation notes:
--   * `join_restrict_level` is the minimum character level (1..65 in 5.8)
--     allowed to apply to the legion. 0 = no restriction. Already a column
--     on `guild` (see 00002 scaffold).
--   * `smallint` in T-SQL → SMALLINT in PG. Existing column is INTEGER
--     (00002 default); we accept SMALLINT and let PG widen at call site.
--   * NO existence guard (bug-for-bug). UPDATE on missing guild = 0 rows.
--   * Returns rows-affected for caller-side sanity check.
--
-- Used by:
--   scripts/handlers/cm_legion_join_restrict.lua  -- on /legion minlevel
--   scripts/lib/guild.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinrestrictlevel(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildjoinrestrictlevel(
    _guild_id              INTEGER,
    _join_restrict_level   SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE guild
       SET join_restrict_level = _join_restrict_level
     WHERE id = _guild_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinrestrictlevel(INTEGER, SMALLINT);
-- +goose StatementEnd
