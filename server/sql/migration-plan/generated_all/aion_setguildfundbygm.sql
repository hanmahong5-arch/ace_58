-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildFundByGM.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildfundbygm(_guild_id INTEGER, _gold BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild SET fund = _gold WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildfundbygm;
-- +goose StatementEnd
