-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItem_SrchItemCntByType.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritem_srchitemcntbytype(_item_name_id TEXT, _enchant_count_from TEXT, _enchant_count_to TEXT, _amount_from TEXT, _amount_to TEXT, _dbid_from TEXT, _dbid_to TEXT, _authorize_count_from TEXT, _authorize_count_to TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			

			declare _sql nvarchar(2000)

			

			_sql := 'SELECT i.name_id, sum(i.amount) amount_sum ' +

						' FROM	user_item i (nolock) ' +

						' JOIN	user_data u (nolock) on i.char_id = u.char_id ' +

						' LEFT JOIN	user_item_option o (nolock) on i.id = o.id and i.char_id = o.char_id ' +

						' WHERE	u.delete_complete_date=0 ' +

						' AND	(i.warehouse in (0,1,3,4,5,6,7) OR (i.warehouse between 30 and 49) OR (i.warehouse between 60 and 79)) '

			

			IF (_item_name_id != 'null')

			BEGIN

				_sql := _sql + 

						' AND ('+_item_name_id+' ) '

			END

			

			IF (_enchant_count_from != 'null' AND _enchant_count_to != 'null')

			BEGIN

				_sql := _sql + 

						' AND o.enchant_count >= '''+_enchant_count_from+''' AND o.enchant_count <= '''+_enchant_count_to+''' '

			END

			

			IF (_amount_from != 'null' AND _amount_to != 'null')

			BEGIN

				_sql := _sql + 

						' AND i.amount >= '''+_amount_from+''' AND i.amount <= '''+_amount_to+''' '

			END

			

			IF (_dbid_from != 'null' AND _dbid_to != 'null')

			BEGIN

				_sql := _sql + 

						' AND i.id >= '''+_dbid_from+''' AND i.id <= '''+_dbid_to+''' '

			END

			

			IF _authorize_count_from != 'null' AND _authorize_count_to != 'null'

			BEGIN

				_sql := _sql + 

						' AND o.authorize_count >= '''+_authorize_count_from+''' and o.authorize_count <= '''+_authorize_count_to+''' '

			END

			

			_sql := _sql + 

						' GROUP BY i.name_id '

		

			exec Sp_ExecuteSQL _sql;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritem_srchitemcntbytype;
-- +goose StatementEnd
