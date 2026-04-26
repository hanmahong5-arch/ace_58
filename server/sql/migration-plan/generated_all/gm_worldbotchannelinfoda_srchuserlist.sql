-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_WorldBotChannelInfoDA_SrchUserList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_worldbotchannelinfoda_srchuserlist(_zone_id_from INTEGER, _zone_id_to INTEGER, _account_id INTEGER, _char_id INTEGER, _user_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	DECLARE _query nvarchar(2000)

	DECLARE _where nvarchar(500)

	

	_query := '

		SELECT	w.char_id, w.account_id, w.world_id as zone_id, u.user_id, u.org_server

		FROM	world_bot_channel_info w

		JOIN	user_data u on u.char_id = w.char_id '



	_where := '1 = 1'

	IF (_zone_id_from != 0)

	BEGIN

		_where := _where + '

		AND	w.world_id >= ' + CONVERT(varchar, _zone_id_from)

	END

	IF (_zone_id_to != 0)

	BEGIN

		_where := _where + '

		AND	w.world_id <= ' + CONVERT(varchar, _zone_id_to)

	END

	IF (_account_id != 0)

	BEGIN

		_where := _where + '

		AND	w.account_id = ' + CONVERT(varchar, _account_id)

	END

	IF (_char_id != 0)

	BEGIN

		_where := _where + '

		AND	w.char_id = ' + CONVERT(varchar, _char_id)

	END

	IF (_user_id != '')

	BEGIN

		_where := _where + '

		AND	user_id = ''' + CONVERT(varchar, _user_id) + ''''

	END

	

	_query := _query + '

		WHERE ' + _where + '

		ORDER BY w.world_id, w.char_id DESC '
RAISE NOTICE '%', _query;

	EXEC (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_worldbotchannelinfoda_srchuserlist;
-- +goose StatementEnd
