-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseInstant.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseinstant(_id INTEGER, _state INTEGER, _permission INTEGER, _inwall INTEGER, _infloor INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	UPDATE house_instant

	SET state = _state, permission = _permission, inwall = _inwall, infloor = _infloor, update_time = NOW()

	WHERE id = _id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseinstant;
-- +goose StatementEnd
