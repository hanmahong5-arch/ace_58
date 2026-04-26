-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssRankingDA_SrchAbyssRankingList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssrankingda_srchabyssrankinglist(_race_type TEXT, _user_id TEXT, _view_count BIGINT, _top_count BIGINT, _from_date TEXT, _to_date TEXT, _world_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(3000)

			

			_sql := ' select * from (' +

						'	select top ' + CONVERT(varchar, _top_count + _view_count) + ' rank() over (order by update_time desc, abyss_ranking) as ''num''' +

						'			, t3.name, t2.best_abyss_rank, t1.guild_id, t1.abyss_ranking, t1.old_ranking, t1.lev, t1.class, t1.race, t1.abyss_point, t1.rank, t1.update_time, t1.rank_updatedate' +

						'			, t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.gender, t2.delete_date, t2.org_server, t2.cur_server,COALESCE(t2.login_server, t2.org_server) login_server' +

						'			, case	WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != ''1970-01-01 00:00:00.000'' and t2.last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' +

						'					WHEN t2.last_login_time != t2.last_logout_time or t2.last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' +

						'					WHEN t2.last_login_time = t2.last_logout_time and t2.last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' +

						'					end as logonoff ' +

						'			, COALESCE(t1.gp,0) as glory_point, COALESCE(gp.ownership_bonus_gp,0) as ownership_bonus_gp ' +

						'	from	abyss_ranking t1(nolock) ' +

						'	left outer join guild t3(nolock) on t1.guild_id = t3.id ' +

						'	left outer join guild t4(nolock) on t1.guild_id = t4.id ' +

						'	left join user_gp_data gp(nolock) on t1.char_id = gp.char_id ' +

						'	left join user_data t2(nolock) on t1.char_id = t2.char_id ' +

						'	where	t1.update_time between '''+_from_date+''' and '''+_to_date+''' ' +

						'	and		t2.org_server='''+_world_id+''' '

			

			IF _user_id != 'null'

			BEGIN

				_sql := _sql +

						'	and		t2.user_id = N'''+_user_id+''''

			END 

			

			IF _race_type != '2'

			BEGIN

				_sql := _sql +

						'	and		t1.race = '''+_race_type+''''

			END

			

			_sql := _sql + 

						'	order by update_time desc, abyss_ranking asc) x ' +

						' where num between ' + convert(varchar, _top_count + 1) + ' and ' + convert(varchar, _top_count + _view_count) +

						' order by update_time desc, abyss_ranking asc '



			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssrankingda_srchabyssrankinglist;
-- +goose StatementEnd
