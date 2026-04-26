-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchUseBotChannelList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchusebotchannellist(_world_id INTEGER, _char_id INTEGER, _user_id TEXT, _account_id INTEGER, _account_name TEXT, _use_bot_channel TEXT, _page_num INTEGER, _view_count INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _query	nvarchar(3000)

			declare _where	nvarchar(1000)

			declare _order_col	nvarchar(100)

			

			_order_col := 'char_id desc'

			_where := '

				where	delete_date = 0

				and		org_server = ' + CONVERT(nvarchar, _world_id)

			if (_char_id != 0)

				_where := _where + '

				and		u.char_id = ' + CONVERT(nvarchar, _char_id)

			if (_user_id != '')

				_where := _where + '

				and		user_id = ''' + _user_id + ''''

			if (_account_id != 0)

				_where := _where + '

				and		u.account_id = ' + CONVERT(nvarchar, _account_id)

			if (_account_name != '')

				_where := _where + '

				and		account_name = ''' + _account_name + ''''

			if (_use_bot_channel != '')

				_where := _where + '

				and		COALESCE(use_bot_channel, 0) = ' + _use_bot_channel



			_query := '

				select	top(' + CONVERT(nvarchar, _view_count) + ') * 

				from	(

					select	top(' + CONVERT(nvarchar, _page_num*_view_count) + ') ROW_NUMBER() over (order by u.' + _order_col + ') as num

							, u.char_id, user_id, u.account_id, account_name, class, gender, race, lev, builder, create_date, org_server, delete_date, delete_complete_date, delete_type

							, COALESCE(e.use_bot_channel, 0) as use_bot_channel, world, e.use_bot_channel_update_date as bot_update_date,

						case WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900''

						 WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown''

						 WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black''

						 end as logonoff

					from	user_data u(nolock)

					left join user_extra_info e(nolock) on e.char_id = u.char_id ' +

					_where + '

					order by ' + _order_col + '

				) x 

				where	num > ' + CONVERT(nvarchar, (_page_num-1)*_view_count) + '

				order by ' + _order_col

			

			EXEC (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchusebotchannellist;
-- +goose StatementEnd
