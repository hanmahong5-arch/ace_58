-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPunishmentDA_SrchPunishListInuse.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchpunishlistinuse(_account_id TEXT, _char_id TEXT, _status TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	login_id, login_nm, id, account_id, char_id, play_block, status, punish_code, convert(nvarchar,start_date,20 ) start_date, convert(nvarchar,end_date,20 ) end_date, convert(nvarchar,cancel_date,20 ) cancel_date, DATEDIFF(minute,NOW(), end_date) left_min, cancel_reason, remain_minute, DATEDIFF(minute, start_date, end_date) st_end_diffdate, punish_reason 

			from	user_punishment(nolock)

			where	account_id=_account_id and char_id=_char_id and status=''+_status+''

			order by punish_code asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpunishmentda_srchpunishlistinuse;
-- +goose StatementEnd
