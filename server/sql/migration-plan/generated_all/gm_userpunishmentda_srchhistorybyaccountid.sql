-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPunishmentDA_SrchHistoryByAccountID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchhistorybyaccountid(_account_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	login_id, login_nm, id, p.account_id, p.char_id, play_block, status, punish_code, convert(nvarchar,start_date,20 ) start_date, convert(nvarchar,end_date,20 ) end_date, convert(nvarchar,cancel_date,20 ) cancel_date, DATEDIFF(minute,NOW(), end_date) left_min, cancel_reason, remain_minute, DATEDIFF(minute, start_date, end_date) st_end_diffdate, punish_reason

					, u.user_id

			from user_punishment(nolock) p

			join user_data(nolock) u on u.char_id = p.char_id

			where p.account_id = _account_id

			order by status asc, start_date desc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpunishmentda_srchhistorybyaccountid;
-- +goose StatementEnd
