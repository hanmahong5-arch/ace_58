-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharByAccountID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbyaccountid(_account_id TEXT, _world_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select	delete_type, delete_complete_date, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server, COALESCE(login_server, org_server) login_server,

					convert(nvarchar,create_date,20 ) create_date, convert(char, gender) gender, convert(char, race) race, convert(char, class) class, convert(char, lev) lev, convert(char, builder) builder, exp, world,

					case 

						WHEN last_login_time = last_logout_time and last_login_time != '1970-01-01 00:00:00.000' and last_logout_time > '2007-12-12 00:00:00.000' THEN '#339900'

						WHEN last_login_time != last_logout_time or last_login_time = '1970-01-01 00:00:00.000'  THEN 'brown'

						WHEN last_login_time = last_logout_time and last_login_time != '1970-01-01 00:00:00.000' THEN 'black'				       	  

						end as logonoff

			from	user_data(nolock)

			where	account_id=_account_id and org_server=_world_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharbyaccountid;
-- +goose StatementEnd
