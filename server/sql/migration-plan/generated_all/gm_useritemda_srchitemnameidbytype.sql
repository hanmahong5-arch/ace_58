-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchItemNameIDByType.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchitemnameidbytype(_item_name_id TEXT, _enchant_count_from TEXT, _enchant_count_to TEXT, _amount_from TEXT, _amount_to TEXT, _dbid_from TEXT, _dbid_to TEXT, _view_count TEXT, _top_count TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(2500)

						

			_sql := 'select top ' + _view_count +

					   ' sum(t1.amount) amount, t1.name_id, ' +

					   ' t2.char_id, t2.user_id, t2.account_id, t2.account_name ' +

					   ' from user_item t1(nolock) , user_data t2(nolock) ' +

					   ' where t2.delete_complete_date=''0'' and t1.char_id = t2.char_id and (t1.warehouse=0 or t1.warehouse=1 or t1.warehouse=3 or t1.warehouse=4 or t1.warehouse=5) '

			

			IF _item_name_id != 'null'

			BEGIN

					   _sql := _sql + ' and ('+_item_name_id+' ) ' 

			END 

			

			IF _enchant_count_from != 'null' AND _enchant_count_to != 'null'

			BEGIN					   

					   _sql := _sql + '     and t1.enchant_count >= '''+_enchant_count_from+''' and t1.enchant_count <= '''+_enchant_count_to+''' '

			END

			

			IF _amount_from != 'null' AND _amount_to != 'null'

			BEGIN

					   

					   _sql := _sql + '      and t1.amount >= '''+_amount_from+''' and t1.amount <= '''+_amount_to+''' '

			END

					   

			IF _dbid_from != 'null' AND _dbid_to != 'null'

			BEGIN

					   _sql := _sql +'      and t1.id >= '''+_dbid_from+''' and t1.id <= '''+_dbid_to+''' '

			END

					   

					   _sql := _sql +'       and t1.id not in (select top ' + _top_count + ' t1.id from user_item t1(nolock) , user_data t2(nolock) ' +

									    ' where delete_date=''0'' and t1.char_id = t2.char_id and (t1.warehouse=0 or t1.warehouse=1 or t1.warehouse=6 or t1.warehouse=7 or t1.warehouse=3 or t1.warehouse=4 or t1.warehouse=5) ' 

			

			IF _item_name_id != 'null'

			BEGIN

					   _sql := _sql + ' and ('+_item_name_id+' ) ' 

			END 

					   

			IF _enchant_count_from != 'null' AND _enchant_count_to != 'null'

			BEGIN					   

					   _sql := _sql + '     and t1.enchant_count >= '''+_enchant_count_from+''' and t1.enchant_count <= '''+_enchant_count_to+''' '

			END

					   

			IF _amount_from != 'null' AND _amount_to != 'null'

			BEGIN					   

					   _sql := _sql + '     and t1.amount >= '''+_amount_from+''' and t1.amount <= '''+_amount_to+''' '

			END

					   

			IF _dbid_from != 'null' AND _dbid_to != 'null'

			BEGIN

					   _sql := _sql +'      and t1.id >= '''+_dbid_from+''' and t1.id <= '''+_dbid_to+'''  '

			END

					   

					   

					   _sql := _sql + ' order by t1.char_id asc ' +					   

								         ' ) group by t1.name_id,  t2.char_id, t2.user_id, t2.account_id, t2.account_name      '

			

			

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchitemnameidbytype;
-- +goose StatementEnd
