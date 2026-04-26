-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: Z_SendItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION z_senditem(_to_name TEXT, _from_name TEXT, _title TEXT, _item_id BIGINT, _item_amount BIGINT, _enchant INTEGER, _mana_stone BIGINT, _god_stone BIGINT, _mana_stone_count BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if (_item_id <> 0)

BEGIN


	DECLARE _char_id int

	_char_id := (SELECT char_id FROM user_data WHERE user_id=_to_name and delete_date = 0 and delete_complete_date = 0)

	IF _char_id >0 BEGIN

		DECLARE _dbid bigint

		INSERT INTO user_item (char_id,name_id,amount,slot,warehouse) VALUES (_char_id,_item_id,_item_amount,'0',5)

		_dbid := @_i_d_e_n_t_i_t_y /* LIMIT 1 appended */ LIMIT 1;

		IF _enchant > 0 OR _mana_stone > 0 OR _god_stone > 0 BEGIN



			IF _mana_stone_count = 0 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,0,0,0,0,0,0,_god_stone,0)

			END

			ELSE IF _mana_stone_count = 1 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,0,0,0,0,0,_god_stone,0)

			END

			ELSE IF _mana_stone_count = 2 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,_mana_stone,0,0,0,0,_god_stone,0)

			END

		    ELSE IF _mana_stone_count = 3 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,_mana_stone,_mana_stone,0,0,0,_god_stone,0)

			END

			ELSE IF _mana_stone_count = 4 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,_mana_stone,_mana_stone,_mana_stone,0,0,_god_stone,0)

			END

			ELSE IF _mana_stone_count = 5 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,_mana_stone,_mana_stone,_mana_stone,_mana_stone,0,_god_stone,0)

			END

			ELSE IF _mana_stone_count = 6 BEGIN

				INSERT INTO user_item_option (id, char_id, enchant_count, skin_name_id,stat_enchant_name0,stat_enchant_name1,stat_enchant_name2,stat_enchant_name3,stat_enchant_name4,stat_enchant_name5,proc_tool_nameid,option_count) 

				VALUES (_dbid, _char_id, _enchant, _item_id,_mana_stone,_mana_stone,_mana_stone,_mana_stone,_mana_stone,_mana_stone,_god_stone,0)

			END

		END



		INSERT INTO user_mail (to_id,to_name,from_id,from_name,title,content,item_id,item_nameid,item_amount,express_mail) 

		VALUES (_char_id,_to_name,0,_from_name,_title,N'请查收系统发你的物品',_dbid,_item_id,_item_amount,1)



        select N'发送给[ '+_to_name+N' ]的物品成功'

	END ELSE BEGIN 

        select N'发送失败，角色名不存在：' + _to_name

END


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS z_senditem;
-- +goose StatementEnd
