-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMoveServiceLogDA_SrchGuildNameChange.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermoveservicelogda_srchguildnamechange(_user_id TEXT, _char_id TEXT, _account_name TEXT, _guild_name TEXT, _guild_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(1500)



			_sql := ' select ' +

					   ' t1.change_date, t1.old_name, t1.new_name, t1.item_id, t1.tid, t1.guild_id, ' +

					   ' t1.master_id, t1.master_user_id, t1.master_account_name, t1.master_account_id, t1.class, t1.lev, t1.race, t1.gender, ' +

					   ' t2.delete_complete_date, t2.org_server, t2.delete_date ' +

					   ' from guild_name_change_log t1(nolock), user_data t2(nolock) ' +

					   ' where t1.master_id = t2.char_id '

			

			IF _user_id != 'null'

			BEGIN

				_sql := _sql + ' and t2.user_id = N'''+_user_id+''' '

			END

			

			IF _char_id != 'null'

			BEGIN

				_sql := _sql + ' and t2.char_id = '''+_char_id+''' '

			END

			

			IF _account_name != 'null'

			BEGIN

				_sql := _sql + ' and t2.account_name = '''+_account_name+''' '

			END

			

			IF _guild_name != 'null'

			BEGIN

				_sql := _sql + ' and t1.new_name = N'''+_guild_name+''' '

			END

			

			IF _guild_id != 'null'

			BEGIN

				_sql := _sql + ' and t1.guild_id = '''+_guild_id+''' '

			END

			

			_sql := _sql + ' order by t1.change_date asc '

			

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermoveservicelogda_srchguildnamechange;
-- +goose StatementEnd
