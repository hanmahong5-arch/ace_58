-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarName.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarname(_id BIGINT, _master_id INTEGER, _name TEXT, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




UPDATE user_familiar

SET name = _name, update_time = _update_time

WHERE id = _id AND char_id = _master_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarname;
-- +goose StatementEnd
