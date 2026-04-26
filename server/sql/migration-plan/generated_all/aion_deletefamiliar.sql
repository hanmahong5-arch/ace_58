-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteFamiliar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletefamiliar(_id BIGINT, _master_id INTEGER, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




UPDATE user_familiar

SET update_time = _update_time, deleted = 1

WHERE id = _id AND char_id = _master_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefamiliar;
-- +goose StatementEnd
