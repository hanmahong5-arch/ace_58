-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_CheckOrgChar_local_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_checkorgchar_local_ors(_from_server_id INTEGER, _server_id INTEGER, _char_id INTEGER, _char_name TEXT, _premium INTEGER, _with_account_warehouse INTEGER, _online INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _ret	int

_ret := 0



declare _lev	int

declare	_delete_date	int

declare _guild	int

declare _qina_restrict_value bigint

declare _level_restrict_value int

declare _ap_restrict_value int

declare _gp_restrict_value int

declare _user_qina bigint

declare _user_mail_qina bigint

declare _warehouse_qina bigint

declare _ap	bigint

declare _user_restrict_item_cnt int

declare _vendor_item_cnt int

declare _vendor_log_item_cnt int

declare	_char_name	nvarchar(20)

declare _user_restrict_recipe_cnt int

declare _last_login_time datetime

declare _last_logout_time datetime

declare _house_count int

declare _escrow_count int

declare _house_auction_count int

declare _buddy_count int

declare _account_id int

declare _gp bigint

declare _ownership_bonus_gp int





declare _realtime_move_char_status int



_realtime_move_char_status := (select user_state from user_server_transfer with (nolock) where char_id = _char_id)



-- Max Qina 제한값 얻어오기

_qina_restrict_value := (select value from 

(select top (1) item_name_id, value , world_id from restricted_item with (nolock)

where

RESTRICT_STATUS = 1

and

service_type in (0,2)

and

type = 2

and 

service_class_type = _premium

and

world_id in (0, _server_id)

and

start_date <= NOW() and (end_date is null or NOW() < end_date)

order by world_id desc) as b)



-- min level 제한값 얻어오기

_level_restrict_value := (select value from 

(select top (1) item_name_id, value , world_id from restricted_item with (nolock)

where

RESTRICT_STATUS = 1

and

service_type in (0,2)

and

type = 4

and

world_id in (0, _server_id)

and 

service_class_type = _premium

and

start_date <= NOW() and (end_date is null or NOW() < end_date)

order by world_id desc) as b)



-- ap 제한값 얻어오기

_ap_restrict_value := (select value from 

(select top (1) item_name_id, value , world_id from restricted_item with (nolock)

where

RESTRICT_STATUS = 1

and

service_type in (0,2)

and

type = 3

and

world_id in (0, _server_id)

and 

service_class_type = _premium

and

start_date <= NOW() and (end_date is null or NOW() < end_date)

order by world_id desc) as b)





-- gp 제한값 얻어오기

/*

_gp_restrict_value := (select value from 

(select top (1) item_name_id, value , world_id from restricted_item with (nolock)

where

RESTRICT_STATUS = 1

and

service_type in (0,2)

and

type = 6

and

world_id in (0, _server_id)

and 

service_class_type = _premium

and

start_date <= NOW() and (end_date is null or NOW() < end_date)

order by world_id desc) as b)

*/





_lev := 0

SELECT lev, _delete_date = delete_date, _guild = guild_id, _ap = abyss_point, _char_name = user_id, _last_login_time= last_login_time, _last_logout_time = last_logout_time, _account_id=account_id INTO _lev   from user_data (nolock) where char_id = _char_id

if _lev <> 0

begin

	if _char_name <> _char_name and not exists(select id from user_name_change_log where char_id = _char_id and old_name = _char_name)

		_ret := -10103

	--if (_last_login_time > _last_logout_time or _last_logout_time > dateadd(mi, -10, NOW()) ) _ret := -100

	--if (_online != 0 and _realtime_move_char_status != 1) _ret := -101

	if (_level_restrict_value is not null and _lev < _level_restrict_value)	_ret := -10001	-- 레벨 제한 조건 불충족

	if _guild <> 0		_ret := -10003	-- guild에 가입해 있음

	if _delete_date<> 0	_ret := -10009	-- 삭제 대기 또는 삭제 상태임

	if (_ap_restrict_value is not null and _ap > _ap_restrict_value) _ret := -10004	-- AP 제한 조건 불충족

	

	select _gp = COALESCE(glory_point, 0), _ownership_bonus_gp = COALESCE(ownership_bonus_gp, 0) from user_gp_data where char_id = _char_id

	--if (_gp > _gp_restrict_value) _ret := -10016

	if (_ownership_bonus_gp > 0 ) _ret := -10017



	if exists(select * from user_punishment where char_id = _char_id and status = 0 and ((play_block = 1 and end_date > NOW()) or (play_block = 0 and Remain_Minute > 0)) and (punish_code != 101 and punish_code != 102))

		_ret := -10010	-- 제재 상태에 있음



	_user_qina := (select COALESCE(sum(amount), 0)

	from user_item with (nolock)

	where char_id = _char_id and name_id = 182400001

	and warehouse in (0, 1))



	_user_mail_qina := (select COALESCE(sum(money), 0) from user_mail with (nolock) where to_id = _char_id)

	



	if _with_account_warehouse > 0 

	begin

		_warehouse_qina := (select COALESCE(sum(amount), 0)

		from user_item with (nolock)

		where char_id = _account_id and name_id = 182400001

		and warehouse in (6, 7))

	end

	else begin

		_warehouse_qina := 0

	end	

	

	declare _sum_sold_price bigint

	_sum_sold_price := 0



	select _sum_sold_price = _sum_sold_price + CAST(COALESCE(SUM(sold_price - after_fee), 0) AS bigint)

	from vendor_log_dark with (nolock) where char_id = _char_id



	select _sum_sold_price = _sum_sold_price + CAST(COALESCE(SUM(sold_price - after_fee), 0) AS bigint)

	from vendor_log_light with (nolock) where char_id = _char_id

	

	_user_qina := _user_qina + _user_mail_qina + _warehouse_qina + _sum_sold_price



	if (_qina_restrict_value is not null and _user_qina is not null and _user_qina >= _qina_restrict_value)

	begin

		_ret := -10005	-- qina 제약에 걸림

	end





	_user_restrict_item_cnt := (select count(*) from (

	select restricted_item.item_name_id as name_id, restricted_item.value as item_count, * from restricted_item with (nolock)

	join (

		select max(world_id) as restrict_world_id, item_name_id as restrict_item_name_id from restricted_item with (nolock)

		where

		RESTRICT_STATUS = 1

		and

		service_type in (0,2)

		and

		type = 1

		and

		world_id in (0, _server_id)

		and

		service_class_type = _premium

		and

		start_date <= NOW() and (end_date is null or NOW() < end_date)

		group by item_name_id) as b

	on restricted_item.item_name_id = b.restrict_item_name_id and restricted_item.world_id = b.restrict_world_id

	where

	RESTRICT_STATUS = 1

	and

	service_type in (0,2)

	and

	type = 1

	and 

	service_class_type = _premium

	and

	restricted_item.world_id in (0, _server_id)

	and

	start_date <= NOW() and (end_date is null or NOW() < end_date)

	) as a

	join (select name_id, sum(amount) as amount from (Select * From user_item  with (nolock) where char_id = _char_id) as tmpItem Where warehouse in (0, 1, 4, 5, 154) or (warehouse between 30 and 49) or (warehouse between 60 and 79)  group by name_id) as u

	on a.item_name_id = u.name_id and a.item_count <= u.amount)



	if _user_restrict_item_cnt > 0

		_ret := -10006	-- Item 제약에 걸림



	_user_restrict_recipe_cnt := (select count(*) from (

	select restricted_item.item_name_id as name_id, * from restricted_item with (nolock)

	join (

		select max(world_id) as restrict_world_id, item_name_id as restrict_item_name_id from restricted_item with (nolock)

		where

		RESTRICT_STATUS = 1

		and

		service_type in (0,2)

		and

		type = 5

		and

		service_class_type = _premium

		and

		world_id in (0, _server_id)

		and

		start_date <= NOW() and (end_date is null or NOW() < end_date)

		group by item_name_id) as b

	on restricted_item.item_name_id = b.restrict_item_name_id and restricted_item.world_id = b.restrict_world_id

	where

	RESTRICT_STATUS = 1

	and

	service_type in (0,2)

	and

	type = 5

	and

	service_class_type = _premium

	and

	restricted_item.world_id in (0, _server_id)

	and

	start_date <= NOW() and (end_date is null or NOW() < end_date)

	) as a

	join (select recipe_id from user_recipe with (nolock) where char_id = _char_id) as u

	on a.item_name_id = u.recipe_id)



	if _user_restrict_recipe_cnt > 0

		_ret := -10012	-- recipe 제약에 걸림





	if _with_account_warehouse > 0

	begin

		_user_restrict_item_cnt := (select count(*) from (

		select restricted_item.item_name_id as name_id, restricted_item.value as item_count, * from restricted_item with (nolock)

		join (

			select max(world_id) as restrict_world_id, item_name_id as restrict_item_name_id from restricted_item with (nolock)

			where

			RESTRICT_STATUS = 1

			and

			service_type in (0,2)

			and

			type = 1

			and

			service_class_type = _premium

			and

			world_id in (0, _server_id)

			and

			start_date <= NOW() and (end_date is null or NOW() < end_date)

			group by item_name_id) as b

		on restricted_item.item_name_id = b.restrict_item_name_id and restricted_item.world_id = b.restrict_world_id

		where

		RESTRICT_STATUS = 1

		and

		service_type in (0,2)

		and

		type = 1

		and

		service_class_type = _premium

		and

		restricted_item.world_id in (0, _server_id)

		and

		start_date <= NOW() and (end_date is null or NOW() < end_date)

		) as a

		join (select name_id, sum(amount) as amount from (Select * From user_item  with (nolock) where char_id = _account_id) as tmpItem Where warehouse in (6,7) group by name_id) as u

		on a.item_name_id = u.name_id and a.item_count <= u.amount)



		if _user_restrict_item_cnt > 0

			_ret := -10006	-- Item 제약에 걸림

	end



/* 

-- 벤더에 등록된 아이템이 있는지 확인

*/

/*

	_vendor_item_cnt := 0

	_vendor_item_cnt := (select count(*)

						from vendor_item_dark with (nolock)

						where char_id = _char_id)



	if _vendor_item_cnt > 0

		_ret := -10007	-- 벤더 등록 아이템 존재



	_vendor_item_cnt := (select count(*)

						from vendor_item_light with (nolock)

						where char_id = _char_id)



	if _vendor_item_cnt > 0

		_ret := -10007	-- 벤더 등록 아이템 존재

		



-- 정산 안한 아이템이 있는지 확인

	_vendor_log_item_cnt := 0;

	_vendor_log_item_cnt := (select count(*)

						from vendor_log_dark with (nolock)

						where char_id = _char_id)



	if _vendor_log_item_cnt > 0

		_ret := -10008	-- 정산 안한 아이템 존재



	_vendor_log_item_cnt := (select count(*)

						from vendor_log_light with (nolock)

						where char_id = _char_id)



	if _vendor_log_item_cnt > 0

		_ret := -10008	-- 정산 안한 아이템 존재

*/



/* 

-- 일반형 하우스 있는지 여부 확인

*/

	_house_count := 0;

	_house_count := (select count(*)

						from house_field with (nolock)

						where owner_id = _char_id)



	if _house_count > 0

		_ret := -10011	-- 일반형 하우스 있음

		

/* 

-- escrow 에 등록된 것이 있는지 여부 확인

*/

	_escrow_count := 0;

	_escrow_count := (select count(*)

						from user_escrow with (nolock)

						where seller = _char_id and state = 1)



	if _escrow_count > 0

		_ret := -10014	-- escrow리스트에 있음

		

/*

-- 경매 등록 상태 체크

   - 경매에 올린 상태: sellerID , state = 0

   - 경매 입찰 상태: buyerID, state = 1

*/

	_house_auction_count := 0;

	_house_auction_count := (select COUNT(*)

								from user_auction with (nolock)

								where (sellerID = _char_id and state = 0) or (buyerID = _char_id and state = 1))

	

	if 	_house_auction_count > 0

		_ret := -10013

		



	

	if exists (select complete_date from game_money_trade where seller =  _char_id and complete_date is NULL) 

		_ret := -10105



		



	

/*

-- 서버간 친구 있는지 여부 확인



*/		

/*

	_buddy_count := 0;

	_buddy_count := (select count(*)

						from user_buddy_inter with (nolock)

						where char_id = _char_id)



	if _buddy_count > 0

		_ret := -10015	-- 서버간 친구 리스트가 있음

*/		



end

else

begin

	_ret := -10103	-- 캐릭터 없음

end



select _ret as result;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_checkorgchar_local_ors;
-- +goose StatementEnd
