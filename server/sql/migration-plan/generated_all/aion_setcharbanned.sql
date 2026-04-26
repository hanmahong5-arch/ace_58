-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharBanned.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharbanned(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data 

SET is_banned=1, change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) 

WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharbanned;
-- +goose StatementEnd
