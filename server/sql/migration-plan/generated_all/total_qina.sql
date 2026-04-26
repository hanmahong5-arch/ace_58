-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: total_qina.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION total_qina()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

		set ansi_warnings off



		declare _rs_inven bigint, _rs_account bigint, _rs_guild bigint

				, _rs_vendor_light bigint, _rs_vendor_dark bigint, _rs_mail bigint

				, _rs_attach bigint, _rs_attach_account bigint

		

		-- 인벤 0

		SELECT COALESCE(sum(amount),0) INTO _rs_inven

		from user_item t1(nolock), user_data t2(nolock) 

		where t1.char_id=t2.char_id 

		and t2.delete_complete_date=0 

		and t1.name_id=182400001 

		and t1.warehouse=0



		-- 계정 창고 6 7

		select _rs_account = COALESCE(sum(amount),0)

		from user_item (nolock)

		where char_id in

		(

			select distinct account_id

			from user_data (nolock)

			where delete_complete_date=0

		)

		and name_id=182400001

		and (warehouse=6 or warehouse=7)



		-- 길드 3

		select _rs_guild = COALESCE(sum(fund),0)

		from guild (nolock)

		where delete_time=0	and fund > 0



		-- 중개등록 4

		select _rs_vendor_light = COALESCE(sum(sold_price),0)

		from vendor_log_light t1(nolock), user_data t2(nolock) 

		where t1.char_id=t2.char_id 

		and t2.delete_complete_date=0

		

		select _rs_vendor_dark = COALESCE(sum(sold_price),0)

		from vendor_log_dark t1(nolock), user_data t2(nolock) 

		where t1.char_id=t2.char_id 

		and t2.delete_complete_date=0



		-- 우편 5

		select _rs_mail = COALESCE(sum(t1.money),0)

		from user_mail t1(nolock), user_data t2(nolock)

		where t1.money > 0 

		and t1.to_id=t2.char_id

		and t2.delete_complete_date=0



		-- 압류 50

		select _rs_attach = COALESCE(sum(amount),0)

		from user_item t1(nolock), user_data t2(nolock)

		where t1.char_id=t2.char_id

		and t2.delete_complete_date=0

		and t1.name_id=182400001

		and t1.warehouse=50



		-- 길드압류 53

		-- 키나 압류 못 함. 단, 일반 템 압류는 가능



		-- 계정 창고 압류 56 57

		select _rs_attach_account = COALESCE(sum(amount),0)

		from user_item (nolock)

		where char_id in

		(

			select distinct account_id

			from user_data (nolock)

			where delete_complete_date=0

		)

		and name_id=182400001

		and (warehouse=56 or warehouse=57)



		select _rs_inven inven, _rs_account account, _rs_guild guild, 

			   _rs_vendor_light vendor_light, _rs_vendor_dark vendor_dark, _rs_mail mail, _rs_attach attach,_rs_attach_account attach_account,

			   _rs_inven+_rs_account+_rs_guild+_rs_vendor_light+_rs_vendor_dark+_rs_mail as total_qina

		


		return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS total_qina;
-- +goose StatementEnd
