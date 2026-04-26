-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildFundDeposit.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildfunddeposit(_guild_id INTEGER, _gold BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild SET fund = fund + _gold WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildfunddeposit;
-- +goose StatementEnd
