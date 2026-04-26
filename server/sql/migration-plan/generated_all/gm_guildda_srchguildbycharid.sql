-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuildByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguildbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off

			

			--SELECT	0 as class, 0 as user_id, 0 as account_id, '' as account_name, 0 as org_server -- 군단장 info

			SELECT	u.class, u.user_id, u.account_id, u.account_name, u.org_server -- 군단장 info

					, g.name, g.id, g.master_id

			FROM	user_data u(nolock)

			JOIN	guild g(nolock) ON g.master_id = u.char_id and g.id = u.guild_id

			WHERE	g.id = (select guild_id from user_data(nolock) where char_id = _char_id) -- 내 레기온

/*

			declare _sql nvarchar(1000)

						

			_sql := ' select t2.name, t2.id, t2.master_id, t1.class, t1.user_id, t1.account_id, t1.account_name, t1.org_server ' +			

					   ' from user_data t1(nolock), guild t2(nolock) ' +

					   ' where t2.id =(select guild_id from user_data(nolock) where char_id='''+_char_id+''') and t2.id=t1.guild_id and t2.master_id=t1.char_id '

								

			exec Sp_ExecuteSQL _sql

*/


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguildbycharid;
-- +goose StatementEnd
