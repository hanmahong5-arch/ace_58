-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_AddCompound.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_addcompound(_char_id INTEGER, _item_id BIGINT, _main_item_dbid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin tran	

		

		-- 주무기가 보조무기로 들어갈 경우 체크 : 현재 합성 주무기가 보조무기로 사용중인지

		if EXISTS (select id from user_item(UPDLOCK) where id = _main_item_dbid and main_item_dbid != 0 and char_id = _char_id)

		begin

			rollback tran

			return 1

		end		

		

		-- 주무기가 보조무기로 들어갈 경우 체크 : 주무기가 다른 아이템의 보조무기로 사용중인지

		if EXISTS (select id from user_item(UPDLOCK) where main_item_dbid = _main_item_dbid and warehouse = 16 and char_id = _char_id)

		begin

			rollback tran

			return 2

		end

		

		-- 보조무기가 다른 아이템의 보조무기로 사용 중인지

		if EXISTS (select id from user_item(UPDLOCK) where main_item_dbid = _item_id and warehouse = 16 and char_id = _char_id)

		begin

			rollback tran

			return 3

		end

				

		-- 보조 무기 확인

		if EXISTS (select id from user_item(UPDLOCK) where id = _item_id and main_item_dbid != 0 and char_id = _char_id)

			begin

				rollback tran

				return 4

			end

		else

			begin

				update user_item set warehouse = 16, main_item_dbid = _main_item_dbid, update_date=NOW() where id = _item_id and char_id = _char_id

				if NOT EXISTS (select id from user_item_option where id = _item_id) 

				begin

					insert into user_item_option (id, char_id) values (_item_id, _char_id)

				end

				

				declare _charge_point_main int

				declare _charge_point_sub int

				

				SELECT charge_point INTO _charge_point_main from user_item_charge where id = _main_item_dbid -- 주

				select _charge_point_sub=charge_point from user_item_charge where id = _item_id -- 보

				

				if _charge_point_main is null

					_charge_point_main := 0

				

				if _charge_point_sub is null

					_charge_point_sub := 0

									

				if _charge_point_main > 0 or _charge_point_sub > 0

				begin

					if not EXISTS (select id from user_item_charge(UPDLOCK) where id = _main_item_dbid)						

						update user_item_charge set id = _main_item_dbid, charge_point=_charge_point_sub where id=_item_id						

					else

						begin

							if _charge_point_main < _charge_point_sub

								update user_item_charge set charge_point=_charge_point_sub where id=_main_item_dbid														

						end

				end	

			end

			

		commit tran

		return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_addcompound;
-- +goose StatementEnd
