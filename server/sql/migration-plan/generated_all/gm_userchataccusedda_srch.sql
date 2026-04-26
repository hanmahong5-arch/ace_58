-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserChatAccusedDA_Srch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userchataccusedda_srch(_top_count INTEGER, _page_num INTEGER, _user_id TEXT, _account_name TEXT, _account_id INTEGER, _char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	DECLARE _query nvarchar(2000)

	DECLARE _where nvarchar(1000)

	

	if (_char_id != 0) -- 캐릭터조회 화면

	begin

		-- char_id

		_where := 'u.char_id = ' + convert(varchar, _char_id)

	end

	else

	begin

		_where := '0 < c.penalty_start_time'



		if (COALESCE(_user_id, '') != '')

		begin

			-- user_id

			_where := _where + ' and u.user_id = ''' + _user_id + ''' '

		end

		

		if (COALESCE(_account_name, '') != '')

		begin

			-- user_id

			_where := _where + ' and u.account_name = ''' + _account_name + ''' '

		end

		

		if (_account_id != 0)

		begin

			-- account_id

			_where := _where + ' and u.account_id = ' + convert(varchar, _account_id)

		end

	end



	-- dataset[0] data

	_query := 'SELECT TOP (' + convert(varchar, _top_count) + ') '

				+ ' u.char_id, u.user_id, u.account_id, u.account_name, u.org_server, '

				+ ' c.accused_count, c.penalty_start_time, c.accused_count_penalty, c.last_accused_time '

				+ ' FROM	user_chat_accused c (nolock) '

				+ ' JOIN	user_data u (nolock) ON u.char_id = c.char_id '

				+ ' WHERE ' + _where

				+ ' AND		u.char_id NOT IN (	SELECT TOP (' + convert(varchar, _top_count * (_page_num-1)) + ') u.char_id '

				+ '								FROM	user_chat_accused c (nolock) '

				+ '								JOIN	user_data u (nolock) ON u.char_id = c.char_id '

				+ ' 							WHERE ' + _where

				+ ' 							ORDER BY u.char_id ) '

				+ ' ORDER BY u.char_id '



	-- dataset[1] total

				+ 'SELECT	COUNT(*) as total '

				+ ' FROM	user_chat_accused c (nolock) '

				+ ' JOIN	user_data u (nolock) ON u.char_id = c.char_id '

				+ ' WHERE ' + _where



	EXEC (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userchataccusedda_srch;
-- +goose StatementEnd
