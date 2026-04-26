-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPunishmentDA_SrchPunishInuse.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchpunishinuse(_account_id TEXT, _char_id TEXT, _status TEXT, _punish_code TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT id 

			from	user_punishment(nolock)

			where	account_id=_account_id and char_id=_char_id and status=''+_status+'' and punish_code=''+_punish_code+''

			order by id desc /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpunishmentda_srchpunishinuse;
-- +goose StatementEnd
