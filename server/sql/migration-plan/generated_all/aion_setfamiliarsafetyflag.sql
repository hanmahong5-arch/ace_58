-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarSafetyFlag.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarsafetyflag(_id BIGINT, _master_id INTEGER, _safety_flag INTEGER, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




UPDATE user_familiar

SET safety_flag = _safety_flag, update_time = _update_time

WHERE id = _id AND char_id = _master_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarsafetyflag;
-- +goose StatementEnd
