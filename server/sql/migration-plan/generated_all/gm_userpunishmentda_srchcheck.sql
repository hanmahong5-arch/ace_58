-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPunishmentDA_SrchCheck.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchcheck(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT ID from user_punishment (nolock) where char_id = _char_id and status = 0 and ((play_block = 1 and end_date > NOW()) or (play_block = 0 and Remain_Minute > 0)) and (punish_code != 101 and punish_code != 102)

			
 /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpunishmentda_srchcheck;
-- +goose StatementEnd
