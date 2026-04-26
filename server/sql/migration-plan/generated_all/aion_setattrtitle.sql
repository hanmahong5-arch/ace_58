-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAttrTitle.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setattrtitle(_char_i_d INTEGER, _cur_attr_title_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data 

SET cur_title_attr_id=_cur_attr_title_id, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE char_id  =  _char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setattrtitle;
-- +goose StatementEnd
