-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutPvPEnv.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpvpenv(_type INTEGER, _entity_a INTEGER, _entity_b INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if (_entity_a < _entity_b)

BEGIN

	INSERT pvp_env(type, entity_a, entity_b)

	VALUES (_type, _entity_a, _entity_b)

END

ELSE

BEGIN

	INSERT pvp_env(type, entity_a, entity_b)

	VALUES (_type, _entity_b, _entity_a)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpvpenv;
-- +goose StatementEnd
