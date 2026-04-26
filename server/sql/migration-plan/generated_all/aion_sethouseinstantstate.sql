-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseInstantState.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseinstantstate(_id INTEGER, _state INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	UPDATE house_instant

	SET state = _state, update_time = NOW()

	WHERE id = _id;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseinstantstate;
-- +goose StatementEnd
