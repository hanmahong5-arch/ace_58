-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPetExtra.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetextra(_id BIGINT, _char_id INTEGER, _name TEXT, _visual_data BYTEA)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




declare _change_info_time bigint

_change_info_time := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)



UPDATE user_pet SET name = _name , visual_data = _visual_data, change_info_time = _change_info_time

	WHERE id = _id and char_id = _char_id


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetextra;
-- +goose StatementEnd
