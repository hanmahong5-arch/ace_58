-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_RegacyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_regacyrecovery(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql


		


		set ansi_warnings off

		

		declare _sql nvarchar(2000)

		declare _rs_item_legacy nvarchar(10)

		

		SELECT item_legacy INTO _rs_item_legacy from user_data(nolock) where char_id=_char_id

		

		if _rs_item_legacy != '0'

		begin		

			set IDENTITY_INSERT user_item on

			

			_sql := 'insert into user_item(id, char_id, name_id, slot_id, amount,slot,warehouse,soul_bound,enchant_count,skin_name_id,stat_enchant_0, stat_enchant_val0, stat_enchant_1, stat_enchant_val1,stat_enchant_2, stat_enchant_val2, stat_enchant_3, stat_enchant_val3,stat_enchant_4, stat_enchant_val4, stat_enchant_5, stat_enchant_val5,dye_info, proc_tool_nameid, create_date, update_date, producer,tid, expired_time, option_count, buy_amount, buy_duration,obtain_skin_type, expire_skin_time, main_item_dbid, dynamic_property) select id, char_id, name_id, slot_id, amount,slot,warehouse,soul_bound,enchant_count,skin_name_id,stat_enchant_0, stat_enchant_val0, stat_enchant_1, stat_enchant_val1,stat_enchant_2, stat_enchant_val2, stat_enchant_3, stat_enchant_val3,stat_enchant_4, stat_enchant_val4, stat_enchant_5, stat_enchant_val5,dye_info, proc_tool_nameid, create_date, update_date, producer,tid, expired_time, option_count, buy_amount, buy_duration,obtain_skin_type, expire_skin_time, main_item_dbid, dynamic_property from user_item_legacy_'+_rs_item_legacy+'(nolock) where char_id='+_char_id

			exec Sp_ExecuteSQL _sql

			

			if @_rowcount > 0

			begin 

				_sql := 'delete from user_item_legacy_'+_rs_item_legacy+' where char_id='+_char_id

				exec Sp_ExecuteSQL _sql

			end

			

			set IDENTITY_INSERT user_item off

		end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_regacyrecovery;
-- +goose StatementEnd
