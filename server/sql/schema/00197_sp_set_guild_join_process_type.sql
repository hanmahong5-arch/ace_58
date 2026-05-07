-- AionCore 5.8 — Sprint 1.1a batch 12 port: aion_SetGuildJoinProcessType.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildJoinProcessType.sql
-- Original (T-SQL):
--   UPDATE guild SET join_process_type = @nJoinProcessType WHERE id = @nGuildId
--
-- Translation notes:
--   * `join_process_type` controls how new applicants are admitted to
--     the legion: 0 = closed, 1 = auto-approve, 2 = require-approval
--     (NCSoft enum). Already a column on `guild` (see 00002 scaffold).
--   * `tinyint` in T-SQL → SMALLINT in PG. Existing column is INTEGER
--     (00002 default); we accept SMALLINT and let PG widen at call site.
--   * NO existence guard (bug-for-bug). UPDATE on missing guild = 0 rows.
--   * Returns rows-affected for caller-side sanity check.
--
-- Used by:
--   scripts/handlers/cm_legion_join_policy.lua  -- on /legion joinmode
--   scripts/lib/guild.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinprocesstype(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildjoinprocesstype(
    _guild_id           INTEGER,
    _join_process_type  SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE guild
       SET join_process_type = _join_process_type
     WHERE id = _guild_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildjoinprocesstype(INTEGER, SMALLINT);
-- +goose StatementEnd
