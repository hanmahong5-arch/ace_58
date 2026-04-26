-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuild.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguild(_world_id TEXT, _guild_nm TEXT, _guild_cond TEXT, _race TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off

			

			declare _sql nvarchar(1200)

			declare _sql_tmp nvarchar(100)

			

			_sql_tmp := ''

			

			IF _race != 'null' 

			BEGIN

				_sql_tmp := ' and t2.race = '''+_race+''''

			END 

			

			IF _guild_nm != 'null' and _guild_cond = '2'

			BEGIN

				_sql_tmp := _sql_tmp + ' and t1.level = '''+_guild_nm+''''

			END 



			_sql := ' select top ' + _view_count +

						' t1.level, count(t1.id) cnt , (select user_id from user_data t3 where t1.master_id=t3.char_id) user_id, ' +

						' (select account_id from user_data t3 where t1.master_id=t3.char_id) account_id, ' +

						' (select account_name from user_data t3 where t1.master_id=t3.char_id) account_name, ' +

						' t1.id, t1.name, t1.master_id, t1.rank, t1.point, t1.fund, t1.delete_requested, t1.delete_time, ' +

						' t2.race, t2.org_server ' +

						' , t1.point_max_time ' +

						' from guild t1(nolock), user_data t2(nolock) ' +

						' where t2.org_server='''+_world_id+''' '+_sql_tmp+' and t1.id=t2.guild_id and t1.id not in (select top ' + _top_count + ' t1.id from guild t1(nolock), user_data t2(nolock) ' +

						' where t2.org_server='''+_world_id+''' '+_sql_tmp+' and t1.id=t2.guild_id and t1.master_id=t2.char_id order by t1.id desc) '

			

			IF _guild_nm != 'null' and _guild_cond = '0'

			BEGIN

				_sql := _sql + ' and t1.name = N'''+_guild_nm+''''

			END

			

			IF _guild_nm != 'null' and _guild_cond = '1'

			BEGIN

				_sql := _sql + ' and t2.user_id = N'''+_guild_nm+''''

			END

			

			_sql := _sql + ' group by t1.level, t1.id, t1.name, t1.master_id, t1.rank, t1.point, t1.fund, t1.delete_requested, t1.delete_time, t2.race, t2.org_server, t1.point_max_time '

			_sql := _sql + ' order by t1.id desc '

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguild;
-- +goose StatementEnd
