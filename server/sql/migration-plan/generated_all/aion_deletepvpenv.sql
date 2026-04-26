-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeletePvPEnv.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletepvpenv(_type INTEGER, _entity_a INTEGER, _entity_b INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM pvp_env

WHERE (type=_type and entity_a=_entity_a and entity_b=_entity_b)

	or (type=_type and entity_a=_entity_b and entity_b=_entity_a);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepvpenv;
-- +goose StatementEnd
