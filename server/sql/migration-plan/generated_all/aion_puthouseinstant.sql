-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutHouseInstant.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthouseinstant(_id INTEGER, _state INTEGER, _permission INTEGER, _inwall INTEGER, _infloor INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	INSERT house_instant (id, state, permission, inwall, infloor, update_time, created_time)

	VALUES (_id, _state, _permission, _inwall, _infloor, NOW(), NOW())

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseinstant;
-- +goose StatementEnd
