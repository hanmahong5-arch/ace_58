-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_LegionDominionDA_Srch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_legiondominionda_srch(_world_id INTEGER, _legion_id INTEGER, _legion_name TEXT, _dominion_id INTEGER, _page_num INTEGER, _view_count INTEGER, _order_col TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



			declare _query nvarchar(2000)

			declare _where nvarchar(1000)

			

			_where := '

				where	server_id = ' + convert(varchar, _world_id)

			if (_legion_id != 0)

				_where := _where + '

				and		legion_id = ' + convert(varchar, _legion_id)

			if (_legion_name != '')

				_where := _where + '

				and		name = ''' + _legion_name + ''''

			if (_dominion_id != 0)

				_where := _where + '

				and		dominion_id = ' + convert(varchar, _dominion_id)

			else

				_where := _where + '

				and		dominion_id != 0'

				

			_query := '

				select	top (' + convert(varchar, _view_count) + ') x.*, COALESCE(x.name, ''unknown'') as legion_name

				from (

					select	top (' + convert(varchar, _page_num*_view_count) + ') ROW_NUMBER() over (order by ' + _order_col + ') as num, legion_id, g.name, dominion_id, score, played_time_in_sec, game_end_time, take_over_processed_time, server_id

					from	legion_dominion_rankings d

					LEFT JOIN guild g (nolock) on d.legion_id = g.id '

				+	_where + '

				) x '

				+ _where + ' 

				and		num > ' + convert(varchar, (_page_num-1)*_view_count)

				+ '

				order by ' + _order_col



			EXEC (_query);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_legiondominionda_srch;
-- +goose StatementEnd
