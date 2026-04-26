-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharByAccountIDAndStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbyaccountidandstatus(_account_id INTEGER, _world_id INTEGER, _include_normal INTEGER, _include_delete INTEGER, _include_delete_completed INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	declare _query nvarchar(1000)

	declare _where_or nvarchar(255)

	

	_query := '

	select	char_id, USER_ID, account_id, account_name, race, class, gender

			, org_server, cur_server, world, builder, lev

			, create_date, last_login_time, last_logout_time

			, delete_date, delete_complete_date, delete_type, login_server

	from	user_data (nolock)

	where	account_id = ' + convert(nvarchar, _account_id) + '

	and		org_server = ' + convert(nvarchar, _world_id)

	

	_where_or := '1 != 1'

	if (_include_normal <> 0)

	begin

		_where_or := _where_or + ' or (delete_date = 0 and delete_complete_date = 0)'

	end

	if (_include_delete <> 0)

	begin

		_where_or := _where_or + ' or (delete_date != 0 and delete_complete_date = 0)'

	end

	if (_include_delete_completed <> 0)

	begin

		_where_or := _where_or + ' or (delete_complete_date != 0)'

	end

	_where_or := '

	and		(' + _where_or + ')'

	

	_query := _query + _where_or



	exec (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharbyaccountidandstatus;
-- +goose StatementEnd
