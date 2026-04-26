-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMailDA_SrchMyMailByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermailda_srchmymailbycharid(_char_id TEXT, _mail_type INTEGER, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off

				

			declare _sql nvarchar(1300)

			

			_sql := ' select top '+ _view_count + ' t1.id, t1.to_id, t1.to_name, t1.from_id, t1.from_name, t1.title, t1.item_id, t1.item_nameid, t1.item_amount, t1.money, t1.state, t1.arrive_time, t1.express_mail, t1.abyss_point ' +

					    ' from user_mail t1(nolock) '					    

		

			IF _mail_type = 1

				_sql := _sql + ' where (t1.from_id = '''+_char_id+''') '

			ELSE IF _mail_type = 2		

				_sql := _sql + ' where (t1.to_id = '''+_char_id+''') '				

				

			_sql := _sql + ' and t1.id not in (select top ' + _top_count + ' id from user_mail(nolock) '

				

			IF _mail_type = 1

				_sql := _sql + ' where (from_id = '''+_char_id+''') '

			ELSE IF _mail_type = 2		

				_sql := _sql + ' where (to_id = '''+_char_id+''') '	

				

			_sql := _sql + ' order by id desc ) '

				

				

			_sql := _sql + ' order by t1.id desc '

			

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermailda_srchmymailbycharid;
-- +goose StatementEnd
