-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetTitle.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settitle(_char_i_d INTEGER, _cur_title_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data 

SET cur_title_id=_cur_title_id, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE char_id  =  _char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settitle;
-- +goose StatementEnd
