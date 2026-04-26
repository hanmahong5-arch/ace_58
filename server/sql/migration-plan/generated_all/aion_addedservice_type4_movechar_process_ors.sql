-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_Process_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_process_ors(_db_user_id TEXT, _db_passwd TEXT, _from_server INTEGER, _from_char_id INTEGER, _from_char_name TEXT, _server INTEGER, _char_id INTEGER, _char_name TEXT, _premium INTEGER, _with_account_warehouse INTEGER, _char_id INTEGER, _ret INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE





_char_id := 0

if _char_id is null

	_char_id := 0



declare _connect_string	nvarchar(256)

_connect_string := ''



declare _server_name  nvarchar(128)

_server_name := ''

declare _database_name  nvarchar(64)

_database_name := ''

SELECT datasource, _database_name = database_name INTO _server_name from AionAddedService_Servername where server_id = _from_server

if @_rowcount = 0

begin

	_ret := -10104

	return

end



declare _db_info nvarchar(256)

_db_info := '''' + _server_name + ''';''' + _db_user_id + ''';''' + _db_passwd + ''''



declare _gp_restrict_value int

_gp_restrict_value := (select value from 

(select top (1) item_name_id, value , world_id from restricted_item with (nolock)

where

RESTRICT_STATUS = 1

and

service_type in (0,2)

and

type = 6

and

world_id in (0, _server)

and 

service_class_type = _premium

and

start_date <= NOW() and (end_date is null or NOW() < end_date)

order by world_id desc) as b)





-- Local에 있는 캐릭터 삭제 처리

-- delete_type = 10000번



declare _delete_date int

_delete_date := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0);



if _char_id <> 0

begin

	update user_data 

		set delete_date = _delete_date, 

			delete_complete_date = _delete_date, 

			delete_type	= 10000	-- 캐릭터 이전으로 인한 삭제

		where char_id = _char_id



	if @_error <> 0 

	begin 

		_ret := -11001	-- 기존 캐릭터 삭제 오류

		return

	end

end





IF EXISTS (SELECT object_id FROM sys.tables WHERE name IN ('temp_item_index_change_info'))

BEGIN

	drop table temp_item_index_change_info

END



CREATE TABLE temp_item_index_change_info

(

	old_id bigint,

	new_id bigint,

	name_id int

)



-- 캐릭터 정보 이전 

declare _sql	nvarchar(4000)

declare _from_char_name_real nvarchar(20)



declare _account_id int

_account_id := 0





_sql := 'SELECT user_id, _account_id = account_id '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select user_id, account_id INTO _from_char_name_real from ' + _database_name + '.user_data with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') '

			



--PRINT N'query run :' + _sql



exec sp_executesql _sql, N'_from_char_name_real nvarchar(20) output, _account_id int output', _from_char_name_real output, _account_id output



if @_error <> 0 or _from_char_name_real is null

begin 

	_ret := -11002	-- Character Insert Error!!!

	GOTO error_process

end



--print N'account id => ' + cast(_account_id as nvarchar)



declare _char_count_light int

select _char_count_light = COUNT(char_id) from user_data where account_id = _account_id and delete_complete_date = 0 and delete_date = 0 and race = 0



declare _char_count_dark int

select _char_count_dark = COUNT(char_id) from user_data where account_id = _account_id and delete_complete_date = 0 and delete_date = 0 and race = 1



declare _from_char_name_changed int

if _from_char_name_real <> _from_char_name

begin

	_from_char_name_changed := 0

	_sql := 'select _from_char_name_changed = id '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select id from ' + _database_name + '.user_name_change_log with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' and old_name = ''''' + _from_char_name + '''''  '') '



	exec sp_executesql _sql, N'_from_char_name_changed int output', _from_char_name_changed output

	if _from_char_name_changed = 0

	begin

		_ret := -11002	-- Character Insert Error!!!

		GOTO error_process

	end

end



if _char_name is null

	_char_name := _from_char_name_real



_sql := 'INSERT user_data ('

+'user_id,'

+'account_id,'

+'account_name,'

+'race,'

+'class,'

+'is_banned,'

+'gender,'

+'head_face_color,'

+'head_hair_color,'

+'head_face_type,'

+'head_hair_type,'

+'name_id,'

+'guild_id,'

+'guild_rank,'

+'guild_intro,'

+'guild_nickname,'

+'recreate_guild_time,'

+'org_server,'

+'cur_server,'

+'world,'

+'xlocation,'

+'ylocation,'

+'zlocation,'

+'dir,'

+'last_normal_world,'

+'last_normal_xlocation,'

+'last_normal_ylocation,'

+'last_normal_zlocation,'

+'last_normal_dir,'

+'death_count,'

+'temporary_lost_exp,'

+'resurrect_world,'

+'resurrect_xlocation,'

+'resurrect_ylocation,'

+'resurrect_zlocation,'

+'builder,'

+'now_hit,'

+'now_mana,'

+'exp,'

+'abyss_point,'

+'lev,'

+'stigmaPoint,'

+'event,'

+'create_date,'

+'petition_msg,'

+'jobfaction_id,'

+'jobfaction_rank,'

+'jobfaction_friendship,'

+'npcfaction_id,'

+'npcfaction_rank,'

+'cur_title_id,'

+'last_login_time,'

+'last_logout_time,'

+'playtime,'

+'fly_gauge,'

+'max_fly_gauge,'

+'fly_cool_time,'

+'delete_date,'

+'inventory_growth,'

+'char_warehouse_growth,'

+'cur_title_attr_id,'

+'daily_comment '

+') '

+'select '

+'cast(f.org_server as nvarchar(4))+''s''+replace(ltrim(replace(replace(upper(master.fn_varbintohexstr(f.char_id)), ''0'', '' ''), ''X'', '' '')), '' '', ''0''),'

+'f.account_id,'

+'f.account_name,'

+'f.race,'

+'f.class,'

+'f.is_banned,'

+'f.gender,'

+'f.head_face_color,'

+'f.head_hair_color,'

+'f.head_face_type,'

+'f.head_hair_type,'

+'f.name_id,'

+'f.guild_id,'

+'f.guild_rank,'

+'f.guild_intro,'

+'f.guild_nickname,'

+'f.recreate_guild_time,'

+cast(_server as nvarchar)+','

+cast(_server as nvarchar)+','

+'f.world,'

+'f.xlocation,'

+'f.ylocation,'

+'f.zlocation,'

+'f.dir,'

+'f.last_normal_world,'

+'f.last_normal_xlocation,'

+'f.last_normal_ylocation,'

+'f.last_normal_zlocation,'

+'f.last_normal_dir,'

+'f.death_count,'

+'f.temporary_lost_exp,'

+'f.resurrect_world,'

+'f.resurrect_xlocation,'

+'f.resurrect_ylocation,'

+'f.resurrect_zlocation,'

+'f.builder,'

+'f.now_hit,'

+'f.now_mana,'

+'f.exp,'

+'f.abyss_point,'

+'f.lev,'

+'f.stigmaPoint,'

+'f.event,'

+'f.create_date,'

+'f.petition_msg,'

+'f.jobfaction_id,'

+'f.jobfaction_rank,'

+'f.jobfaction_friendship,'

+'f.npcfaction_id,'

+'f.npcfaction_rank,'

+'f.cur_title_id,'

+'f.last_login_time,'

+'f.last_logout_time,'

+'f.playtime,'

+'f.fly_gauge,'

+'f.max_fly_gauge,'

+'f.fly_cool_time,'

+'f.delete_date,'

+'f.inventory_growth,'

+'f.char_warehouse_growth,'

+'f.cur_title_attr_id,'

+'f.daily_comment '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select * from ' + _database_name + '.user_data with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') as f'



exec (_sql)



if @_error <> 0	or @_rowcount = 0

begin 

	_ret := -11002	-- Character Insert Error!!!

	GOTO error_process

end



_char_id := @_i_d_e_n_t_i_t_y





_sql := 'update user_data set '

+'head_eye_color=f.head_eye_color,'

+'height_scale=f.height_scale,'

+'head_voice_type=f.head_voice_type,'

+'head_feat_type1=f.head_feat_type1,'

+'head_feat_type2=f.head_feat_type2,'

+'now_flight=f.now_flight,'

+'this_week_compare_time=f.this_week_compare_time,'

+'this_week_abyss_kill_cnt=f.this_week_abyss_kill_cnt,'

+'this_week_abyss_point=f.this_week_abyss_point,'

+'last_week_abyss_kill_cnt=f.last_week_abyss_kill_cnt,'

+'last_week_abyss_point=f.last_week_abyss_point,'

+'total_abyss_kill_cnt=f.total_abyss_kill_cnt,'

+'best_abyss_rank=f.best_abyss_rank,'

+'is_freefly=f.is_freefly,'

+'feat_face_shape=f.feat_face_shape,'

+'feat_forehead_shape=f.feat_forehead_shape,'

+'feat_eye_position=f.feat_eye_position,'

+'feat_eye_glabella=f.feat_eye_glabella,'

+'feat_eye_length=f.feat_eye_length,'

+'feat_eye_height=f.feat_eye_height,'

+'feat_eye_shape=f.feat_eye_shape,'

+'feat_eye_tail=f.feat_eye_tail,'

+'feat_eyeblow_pos=f.feat_eyeblow_pos,'

+'feat_eyeblow_angle=f.feat_eyeblow_angle,'

+'feat_eyeblow_shape=f.feat_eyeblow_shape,'

+'feat_nose_pos=f.feat_nose_pos,'

+'feat_nose_bridge=f.feat_nose_bridge,'

+'feat_nose_side=f.feat_nose_side,'

+'feat_nose_tip=f.feat_nose_tip,'

+'feat_cheek_shape=f.feat_cheek_shape,'

+'feat_mouth_pos=f.feat_mouth_pos,'

+'feat_mouth_size=f.feat_mouth_size,'

+'feat_lip_thickness=f.feat_lip_thickness,'

+'feat_lip_tail=f.feat_lip_tail,'

+'feat_lip_shape=f.feat_lip_shape,'

+'feat_jaw_pos=f.feat_jaw_pos,'

+'feat_jaw_shape=f.feat_jaw_shape,'

+'feat_head_size=f.feat_head_size,'

+'feat_neck_thickness=f.feat_neck_thickness,'

+'feat_neck_length=f.feat_neck_length,'

+'feat_shoulder_size=f.feat_shoulder_size,'

+'feat_upper_size=f.feat_upper_size,'

+'feat_bust_size=f.feat_bust_size,'

+'feat_waist_size=f.feat_waist_size,'

+'feat_hip_size=f.feat_hip_size,'

+'feat_arm_thickness=f.feat_arm_thickness,'

+'feat_hand_size=f.feat_hand_size,'

+'feat_leg_thickness=f.feat_leg_thickness,'

+'feat_foot_size=f.feat_foot_size,'

+'feat_wing_size=f.feat_wing_size,'

+'feat_version=f.feat_version,'

+'optionflags=f.optionflags,'

+'delete_complete_date=f.delete_complete_date,'

+'feat_ear_shape=f.feat_ear_shape,'

+'today_compare_time=f.today_compare_time,'

+'today_abyss_kill_cnt=f.today_abyss_kill_cnt,'

+'today_abyss_point=f.today_abyss_point,'

+'cashitem_inventory_growth=f.cashitem_inventory_growth,'

+'cashitem_warehouse_growth=f.cashitem_warehouse_growth,'

+'feat_face_ratio=f.feat_face_ratio,'

+'accused_count=f.accused_count,'

+'last_accuse_time=f.last_accuse_time,'

+'pay_stat=f.pay_stat,'

+'abyss_point_from_user=f.abyss_point_from_user,'

+'guild_update_date=f.guild_update_date,'

+'delete_type=f.delete_type,'

+'bot_point=f.bot_point,'

+'vital_point=f.vital_point,'

+'pvp_exp=f.pvp_exp,'

+'feat_arm_length=f.feat_arm_length,'

+'feat_leg_length=f.feat_leg_length,'

+'head_lip_color=f.head_lip_color,'

+'feat_shoulder_width=f.feat_shoulder_width,'

+'enhanced_stigma_slot_cnt=f.enhanced_stigma_slot_cnt,'

+'account_punishment=f.account_punishment, '

+'item_legacy=f.item_legacy, '

+'head_bump_type=f.head_bump_type, '

+'head_expression_type=f.head_expression_type, '

+'feat_head_figure=f.feat_head_figure, '

+'today_glory_point=f.today_glory_point, '

+'this_week_glory_point=f.this_week_glory_point, '

+'last_week_glory_point=f.last_week_glory_point, '

+'gotcha_fever_point=f.gotcha_fever_point, '

+'gotcha_fever_expire_time=f.gotcha_fever_expire_time, '

+'absolute_exp=f.absolute_exp, '

+'next_hotspot_use_time=f.next_hotspot_use_time, '

+'change_info_time=' + cast(_delete_date as nvarchar) + ', '

+'head_eye_type=f.head_eye_type,'

+'head_dark_tail=f.head_dark_tail,'

+'head_eye_color2=f.head_eye_color2,'

+'head_eye_lash=f.head_eye_lash,'

+'feat_head_eye_size=f.feat_head_eye_size,'

+'feat_upper_height=f.feat_upper_height,'

+'feat_arm_lower_thickness=f.feat_arm_lower_thickness,'

+'feat_hand_length=f.feat_hand_length,'

+'feat_leg_lower_thickness=f.feat_leg_lower_thickness, '

+'is_jumping_character=f.is_jumping_character, '

+'two_weeks_ago_glory_point=f.two_weeks_ago_glory_point, '

+'three_weeks_ago_glory_point=f.three_weeks_ago_glory_point, '

+'absolute_ap=f.absolute_ap '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select * from ' + _database_name + '.user_data with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') as f '

+' where user_data.char_id = ' + cast(_char_id as nvarchar)



exec (_sql)



if @_error <> 0	or @_rowcount = 0

begin 

	_ret := -11003	-- Character Insert Error!!!

	GOTO error_process

end







insert into user_move_service_log (char_id, char_id_delete, server_id_from, char_id_from, user_id_from, move_date,

				account_id, account_name, race, class, gender, lev, premium, warehouse)

select _char_id, _char_id, _from_server, _from_char_id, _from_char_name_real, NOW(), 

				account_id, account_name, race, class, gender, lev, _premium, _with_account_warehouse

from user_data

where char_id = _char_id





if @_error <> 0 or @_rowcount = 0

begin 

	_ret := -11004

	GOTO error_process

end







CREATE TABLE #temp_user_item_normal

(

	id bigint,

	char_id int,

	name_id int,

	slot_id smallint,

	amount bigint,

	slot tinyint,

	warehouse tinyint,

	create_date datetime,

	update_date datetime,

	producer nvarchar(20),

	tid bigint,

	expired_time int,

	buy_amount smallint,

	buy_duration smallint,

	main_item_dbid bigint,

	dynamic_property int,

	import_id bigint,

	export_id bigint,

	server_of_origin smallint

)





-- Normal 아이템 정보 이전 (그냥 이전)

-- Warehouse Type 0 : 인벤 & 장착

-- Warehouse Type 1 : 개인 창고

-- 6,7 : 계정 창고



-- Item Table 이전 (User 소유)

_sql := 'INSERT #temp_user_item_normal ('

+'id, '

+'char_id,'

+'name_id,'

+'slot_id,'

+'amount,'

+'slot,'

+'warehouse,'

+'create_date,'

+'update_date,'

+'producer,'

+'tid,'

+'expired_time,'

+'buy_amount,'

+'buy_duration,'

+'main_item_dbid, '

+'dynamic_property, '

+'import_id, '

+'export_id, '

+'server_of_origin '

+') '

+'select '

+'f.id, '

+ cast(_char_id as nvarchar) +','

+'f.name_id,'

+'f.slot_id,'

+'f.amount,'

+'f.slot,'

+'f.warehouse,'

+'f.create_date,'

+'f.update_date,'

+'f.producer,'

+'f.tid,'

+'f.expired_time,'

+'f.buy_amount,'

+'f.buy_duration,'

+'f.main_item_dbid, '

+'f.dynamic_property, '

+'f.import_id, '

+'f.export_id, '

+'f.server_of_origin '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select main.* from ' 

+'(select * from ' + _database_name + '.user_item with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ') as main '

+'left join (select * from ' + _database_name +'.user_item with (nolock) where char_id=' + cast(_from_char_id as nvarchar) + ' and warehouse = 16) as sub '

+'on main.id = sub.main_item_dbid '

+'where sub.id is NULL and (main.warehouse IN (0, 1, 4, 16) or main.warehouse between 30 and 49 or main.warehouse between 60 and 79)'') as f '



--PRINT N'query run :' + _sql

exec (_sql)



if @_error <> 0	

begin 

	_ret := -11005	-- Normal Item Insert Error(temp table)!!!

	GOTO error_process

end





-- Item Table 이전 (User 소유)

_sql := 'INSERT #temp_user_item_normal ('

+'id, '

+'char_id,'

+'name_id,'

+'slot_id,'

+'amount,'

+'slot,'

+'warehouse,'

+'create_date,'

+'update_date,'

+'producer,'

+'tid,'

+'expired_time,'

+'buy_amount,'

+'buy_duration,'

+'main_item_dbid, '

+'dynamic_property, '

+'import_id, '

+'export_id, '

+'server_of_origin '

+') '

+'select '

+'f.id, '

+ cast(_account_id as nvarchar) +','

+'f.name_id,'

+'f.slot_id,'

+'f.amount,'

+'f.slot,'

+'f.warehouse,'

+'f.create_date,'

+'f.update_date,'

+'f.producer,'

+'f.tid,'

+'f.expired_time,'

+'f.buy_amount,'

+'f.buy_duration,'

+'f.main_item_dbid, '

+'f.dynamic_property, '

+'f.import_id, '

+'f.export_id, '

+'f.server_of_origin '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select main.* from ' 

+'(select * from ' + _database_name + '.user_item with (nolock) where char_id = ' + cast(_account_id as nvarchar) + ') as main '

+'where (main.warehouse IN (6, 7))'') as f '



if _with_account_warehouse > 0		-- 계정창고 이전 조건인 경우만 이전

begin





	if _char_count_light = 0 

	begin

		DELETE FROM user_item where char_id = _account_id and warehouse = 6

	end

	

	if _char_count_dark = 0 

	begin

		DELETE FROM user_item where char_id = _account_id and warehouse = 7

	end

	



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11006	-- Normal Item Insert Error(temp table)!!!

		GOTO error_process

	end

		

	

end













declare _tmp_item_id bigint

declare _tmp_item_new_id bigint

declare _tmp_name_id int

declare _tmp_warehouse int

declare _tmp_item_amount bigint

declare _tmp_char_id int



declare tmpItem_cursor cursor for

select id, name_id, warehouse, amount from #temp_user_item_normal (nolock)



open tmpItem_cursor 

fetch next from tmpItem_cursor into _tmp_item_id, _tmp_name_id, _tmp_warehouse, _tmp_item_amount



while @_fetch_status = 0

begin

	--PRINT N'query run : Insert Item'



	_tmp_item_new_id := 0

	insert into user_item (

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time, 

			buy_amount, buy_duration, main_item_dbid, dynamic_property, import_id, export_id, server_of_origin

			) 

			select 

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time,

			buy_amount, buy_duration, main_item_dbid, dynamic_property,	import_id, export_id, server_of_origin

			from #temp_user_item_normal (nolock)

			where id = _tmp_item_id



	if @_error <> 0

	begin

		_ret := -21010	-- Item Insert TmpTable Error!!!

		GOTO normal_item_insert_error

	end



	_tmp_item_new_id := @_i_d_e_n_t_i_t_y

	_sql := 'insert into user_item_charge('

				+ ' id, charge_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', charge_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_charge.id, user_item_charge.charge_point from ' + _database_name + '.user_item_charge with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21004	-- 신성정보 Insert Error!!!

		GOTO normal_item_insert_error

	end	

	

	

	-- 아이템 봉인 정보

	_sql := 'insert into user_item_sealed('

				+ 'id, sealExpiredTime, sealState, char_id'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ' , sealExpiredTime, sealState, ' + cast(_char_id as nvarchar) 

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_item_sealed with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21000	-- 봉인정보 Insert Error!!!

		GOTO normal_item_insert_error

	end	

	

	-- user_item_ext 정보		

	_sql := 'insert into user_item_ext('

				+ ' id, char_id, sa_custom1'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_char_id as nvarchar) + ', sa_custom1'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_ext.id, user_item_ext.char_id, user_item_ext.sa_custom1 from ' + _database_name + '.user_item_ext with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11043	-- user_item_ext Insert Error!!!

		GOTO normal_item_insert_error

	end	

		

	-- user_item_option 정보		

	if (_tmp_warehouse = 6 or _tmp_warehouse = 7)

	begin

		_tmp_char_id := _account_id				-- 현재 아이템 부가 테이블중 user_item_option 만 계정창고인 경우 account_id를 사용

	end

	else begin

		_tmp_char_id := _char_id 

	end

	

	_sql := 'insert into user_item_option('

				+ ' id, char_id, soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10) '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_tmp_char_id as nvarchar) + ', soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10 '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_item_option with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11044	-- user_item_option Insert Error!!!

		GOTO normal_item_insert_error

	end	





	-- user_item_polish 정보		

	_sql := 'insert into user_item_polish('

				+ ' id, name_id, random_id, polish_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', name_id, random_id, polish_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select id, name_id, random_id, polish_point from ' + _database_name + '.user_item_polish with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11046	-- user_item_ext Insert Error!!!

		GOTO normal_item_insert_error

	end	

	

	if _tmp_warehouse = 4		-- vendor 등록 아이템

	begin

		--print N'vendor item send mail'

		exec aion_MailWrite _char_id, _char_name, 0, '$$SVR_MOVE_TRADER', '$$SVR_MOVE_TRADE_MAIL_TITLE', '$$SVR_MOVE_TRADE_MAIL_BODY', _tmp_item_new_id, _tmp_name_id, _tmp_item_amount, 0/*money*/, 5/*warehouse*/, _delete_date, 0

	end

	



	-- user_item_ext 정보		

	_sql := 'insert into user_item_freeTrade('

				+ ' id, name_id, freetradestate'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', name_id, freetradestate'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_freeTrade.id, user_item_freeTrade.name_id, user_item_freeTrade.freetradestate from ' + _database_name + '.user_item_freeTrade with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11043	-- user_item_ext Insert Error!!!

		GOTO normal_item_insert_error

	end	

	



	_sql := 'insert into user_item_attribute('

				+ ' id, attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select '

				+ + cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value from ' + _database_name + '.user_item_attribute with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11054	-- user_item_attribute Insert Error!!!

		GOTO normal_item_insert_error

	end

	

	

	_sql := 'insert into user_disassembly_retry('

				+ ' charId, ItemId, retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ') '

				+ ' select '

				+ cast(_char_id as nvarchar) + ', ' + cast(_tmp_item_new_id as nvarchar) + ', retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ ' ''select * from ' + _database_name + '.user_disassembly_retry with (nolock) where ItemId = ' + cast(_tmp_item_id as nvarchar) + ''') '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -12011	-- user_disassembly_retry Error!!!

		GOTO normal_item_insert_error

	end

	

	

	-- 아이템 장비 세트 ( 메일함에 있는 것은 무시한다 )

	_sql := 'insert into user_equipment_change_item('

				+ 'char_id, set_id, eqslot, item_id'

				+ ') '

				+ ' select '

				+ cast(_char_id as nvarchar) + ' , set_id, eqslot, ' + cast(_tmp_item_new_id as nvarchar)

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_equipment_change_item with (nolock) where item_id = ' + cast(_tmp_item_id as nvarchar) + ''') '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -12014	-- user_equipment_change_item  Error!!!

		GOTO normal_item_insert_error

	end	

	

	

	

	fetch next from tmpItem_cursor into _tmp_item_id, _tmp_name_id, _tmp_warehouse, _tmp_item_amount

end

normal_item_insert_error:

close tmpItem_cursor

deallocate tmpItem_cursor

truncate table #temp_user_item_normal

if _ret <> 0	GOTO error_process





CREATE TABLE #temp_user_item

(

	id bigint,

	char_id int,

	name_id int,

	slot_id smallint,

	amount bigint,

	slot tinyint,

	warehouse tinyint,

	create_date datetime,

	update_date datetime,

	producer nvarchar(20),

	tid bigint,

	expired_time int,

	buy_amount smallint,

	buy_duration smallint,

	main_item_dbid bigint,

	dynamic_property int,

	import_id bigint,

	export_id bigint,

	server_of_origin smallint

)



-- Normal 아이템 정보 이전 (그냥 이전)

-- 양손무기합성 아이템 이전

_sql := 'insert into #temp_user_item ('

+'id,'

+'char_id,'

+'name_id,'

+'slot_id,'

+'amount,'

+'slot,'

+'warehouse,'

+'create_date,'

+'update_date,'

+'producer,'

+'tid,'

+'expired_time,'

+'buy_amount,'

+'buy_duration,'

+'main_item_dbid, '

+'dynamic_property, '

+'import_id, '

+'export_id, '

+'server_of_origin '

+') '

+'select '

+'id,'

+ cast(_char_id as nvarchar) +','

+'f.name_id,'

+'f.slot_id,'

+'f.amount,'

+'f.slot,'

+'f.warehouse,'

+'f.create_date,'

+'f.update_date,'

+'f.producer,'

+'f.tid,'

+'f.expired_time,'

+'f.buy_amount,'

+'f.buy_duration,'

+'f.main_item_dbid, '

+'f.dynamic_property, '

+'f.import_id, '

+'f.export_id, '

+'f.server_of_origin '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select main.* from ' 

+'(select * from ' + _database_name + '.user_item with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ') as main '

+'Inner join (select * from ' + _database_name +'.user_item with (nolock) where char_id=' + cast(_from_char_id as nvarchar) + ' and warehouse = 16) as sub '

+'on main.id = sub.main_item_dbid '

+'where sub.id is not NULL and (main.warehouse IN (0, 1, 4, 6, 7) or main.warehouse between 30 and 49 or main.warehouse between 60 and 79)'') as f '

--print _sql

exec (_sql)



if @_error <> 0	

begin 

	_ret := -11032	-- TwoHandWeapon compound Item Insert TmpTable Error!!!

	GOTO error_process

end





declare tmpItem_cursor cursor for

select id from #temp_user_item (nolock)



open tmpItem_cursor 

fetch next from tmpItem_cursor into _tmp_item_id



while @_fetch_status = 0

begin

	_tmp_item_new_id := 0

	insert into user_item (

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time, 

			buy_amount, buy_duration, main_item_dbid, dynamic_property,	import_id, export_id, server_of_origin

			) 

			select 

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time, 

			buy_amount, buy_duration, main_item_dbid, dynamic_property,	import_id, export_id, server_of_origin

			from #temp_user_item (nolock)

			where id = _tmp_item_id



	if @_error <> 0

	begin

		_ret := -11033	-- TwoHandWeapon compound Item Insert TmpTable Error!!!

		GOTO compounde_item_insert_error

	end

	

	_tmp_item_new_id := @_i_d_e_n_t_i_t_y

	insert into temp_item_index_change_info (old_id, new_id, name_id) values(_tmp_item_id, _tmp_item_new_id, _tmp_name_id)



	if @_error <> 0 or @_rowcount = 0

	begin

		_ret := -11034	-- TwoHandWeapon compound Item Insert TmpTable Error!!!

		GOTO compounde_item_insert_error

	end

	

	_sql := 'insert into user_item_charge('

				+ ' id, charge_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', charge_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_charge.id, user_item_charge.charge_point from ' + _database_name + '.user_item_charge with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21012	-- 신성정보 Insert Error!!!

		GOTO compounde_item_insert_error

	end		



	-- user_item_ext 정보		

	_sql := 'insert into user_item_ext('

				+ ' id, char_id, sa_custom1'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_char_id as nvarchar) + ', sa_custom1'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_ext.id, user_item_ext.char_id, user_item_ext.sa_custom1 from ' + _database_name + '.user_item_ext with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21013	-- user_item_ext Insert Error!!!

		GOTO compounde_item_insert_error

	end	

	

	-- user_item_option 정보	

	_sql := 'insert into user_item_option('

				+ ' id, char_id, soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10) '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_char_id as nvarchar) + ', soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10 '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_item_option with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21014	-- user_item_option Insert Error!!!

		GOTO compounde_item_insert_error

	end		

	

	-- user_item_polish 정보		

	_sql := 'insert into user_item_polish('

				+ ' id, name_id, random_id, polish_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', name_id, random_id, polish_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select id, name_id, random_id, polish_point from ' + _database_name + '.user_item_polish with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21016	-- user_item_polish Insert Error!!!

		GOTO compounde_item_insert_error

	end	

	

	-- 아이템 봉인 정보

	_sql := 'insert into user_item_sealed('

				+ 'id, sealExpiredTime, sealState, char_id'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ' , sealExpiredTime, sealState, ' + cast(_char_id as nvarchar) 

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_item_sealed with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21000	-- 봉인정보 Insert Error!!!

		GOTO compounde_item_insert_error

	end		

	



	_sql := 'insert into user_item_attribute('

				+ ' id, attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select '

				+ + cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value from ' + _database_name + '.user_item_attribute with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21017	-- user_item_attribute Insert Error!!!

		GOTO compounde_item_insert_error

	end	

	



	_sql := 'insert into user_disassembly_retry('

				+ ' charId, ItemId, retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ') '

				+ ' select '

				+ cast(_char_id as nvarchar) + ', ' + cast(_tmp_item_new_id as nvarchar) + ', retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ ' ''select * from ' + _database_name + '.user_disassembly_retry with (nolock) where ItemId = ' + cast(_tmp_item_id as nvarchar) + ''') '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -12012	-- user_disassembly_retry Error!!!

		GOTO compounde_item_insert_error

	end

		

	_sql := 'insert into user_equipment_change_item('

				+ 'char_id, set_id, eqslot, item_id'

				+ ') '

				+ ' select '

				+ cast(_char_id as nvarchar) + ' , set_id, eqslot, ' + cast(_tmp_item_new_id as nvarchar)

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_equipment_change_item with (nolock) where item_id = ' + cast(_tmp_item_id as nvarchar) + ''') '



	--PRINT N'query run :' + _sql

	exec (_sql)

	

	if @_error <> 0	

	begin 

		_ret := -12015	-- user_equipment_change_item Error!!!

		GOTO compounde_item_insert_error

	end

	

	fetch next from tmpItem_cursor into _tmp_item_id

end

compounde_item_insert_error:

close tmpItem_cursor

deallocate tmpItem_cursor

if _ret <> 0	GOTO error_process



declare tmpItem_cursor cursor for

select old_id, new_id from temp_item_index_change_info (nolock)



open tmpItem_cursor 

fetch next from tmpItem_cursor into _tmp_item_id, _tmp_item_new_id



while @_fetch_status = 0

begin

	_sql := 'update user_item set main_item_dbid=' + cast(_tmp_item_new_id as nvarchar)

	+' Where char_id=' + cast(_char_id as nvarchar) + ' and main_item_dbid=' + cast(_tmp_item_id as nvarchar)

	exec (_sql)

	if @_error <> 0

	begin

		_ret := -11035	-- TwoHandWeapon compound Item Insert TmpTable Error!!!

		GOTO compounde_item_insert_error2

	end



	fetch next from tmpItem_cursor into _tmp_item_id, _tmp_item_new_id

end





compounde_item_insert_error2:

close tmpItem_cursor

deallocate tmpItem_cursor

truncate table #temp_user_item

truncate table temp_item_index_change_info

if _ret <> 0	GOTO error_process



-- Warehouse Type 5 : 메일

_sql := 'insert into #temp_user_item ('

+'id,'

+'char_id,'

+'name_id,'

+'slot_id,'

+'amount,'

+'slot,'

+'warehouse,'

+'create_date,'

+'update_date,'

+'producer,'

+'tid,'

+'expired_time,'

+'buy_amount,'

+'buy_duration,'

+'main_item_dbid, '

+'dynamic_property, '

+'import_id, '

+'export_id, '

+'server_of_origin '

+') '

+'select '

+'id,'

+ cast(_char_id as nvarchar) +','

+'f.name_id,'

+'f.slot_id,'

+'f.amount,'

+'f.slot,'

+'f.warehouse,'

+'f.create_date,'

+'f.update_date,'

+'f.producer,'

+'f.tid,'

+'f.expired_time,'

+'f.buy_amount,'

+'f.buy_duration,'

+'f.main_item_dbid, '

+'f.dynamic_property, '

+'f.import_id, '

+'f.export_id, '

+'f.server_of_origin '

+'from openrowset (''SQLOLEDB'', ' + _db_info + ','

+'''select * from ' + _database_name + '.user_item with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' and warehouse = 5'') as f '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11006	-- Mail Item Insert TmpTable Error!!!

	GOTO error_process

end



_tmp_item_id := 0

_tmp_item_new_id := 0



declare tmpItem_cursor cursor for

select id, warehouse from #temp_user_item (nolock)



open tmpItem_cursor 

fetch next from tmpItem_cursor into _tmp_item_id, _tmp_warehouse



while @_fetch_status = 0

begin

	_tmp_item_new_id := 0

	insert into user_item (

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time, 

			buy_amount, buy_duration, main_item_dbid, dynamic_property,	import_id, export_id, server_of_origin

			) 

			select 

			char_id, name_id, slot_id, amount,slot,warehouse, create_date, update_date, producer,tid, expired_time, 

			buy_amount, buy_duration, main_item_dbid, dynamic_property,	import_id, export_id, server_of_origin

			from #temp_user_item (nolock)

			where id = _tmp_item_id



	if @_error <> 0

	begin

		_ret := -11007	-- Mail Item Insert Error!!!

		GOTO item_insert_error

	end



	_tmp_item_new_id := @_i_d_e_n_t_i_t_y

	insert into temp_item_index_change_info (old_id, new_id) values(_tmp_item_id, _tmp_item_new_id)



	if @_error <> 0 or @_rowcount = 0

	begin

		_ret := -11008	-- tmp Item index change info Insert Error!!!

		GOTO item_insert_error

	end

	

	_sql := 'insert into user_item_charge('

				+ ' id, charge_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', charge_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_charge.id, user_item_charge.charge_point from ' + _database_name + '.user_item_charge with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21011	-- 신성정보 Insert Error!!!

		GOTO item_insert_error

	end	

		

		

	-- user_item_ext 정보		

	_sql := 'insert into user_item_ext('

				+ ' id, char_id, sa_custom1'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_char_id as nvarchar) + ', sa_custom1'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_ext.id, user_item_ext.char_id, user_item_ext.sa_custom1 from ' + _database_name + '.user_item_ext with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21014	-- user_item_ext Insert Error!!!

		GOTO item_insert_error

	end

	

	

	-- user_item_option 정보		

	if (_tmp_warehouse = 6 or _tmp_warehouse = 7)

	begin

		_tmp_char_id := _account_id				-- 현재 아이템 부가 테이블중 user_item_option 만 계정창고인 경우 account_id를 사용

	end

	else begin

		_tmp_char_id := _char_id 

	end	

	_sql := 'insert into user_item_option('

				+ ' id, char_id, soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10) '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', ' + cast(_tmp_char_id as nvarchar) + ', soul_bound, enchant_count, skin_name_id, '

				+ ' stat_enchant_name0, stat_enchant_0, stat_enchant_val0, '

				+ ' stat_enchant_name1, stat_enchant_1, stat_enchant_val1, '

				+ ' stat_enchant_name2, stat_enchant_2, stat_enchant_val2, '

				+ ' stat_enchant_name3, stat_enchant_3, stat_enchant_val3, '

				+ ' stat_enchant_name4, stat_enchant_4, stat_enchant_val4, '

				+ ' stat_enchant_name5, stat_enchant_5, stat_enchant_val5, '

				+ ' option_count, dye_info, proc_tool_nameid, obtain_skin_type, '

				+ ' expire_skin_time, expire_dye_time, random_option, limit_enchant_count, reidentify_count, '

				+ ' authorize_count, vanish_point, enchant_prob_addition, option_prob_addition, proc_break_count, proc_break_flag, '

				+ ' keyNameId, exceedState, exceedSkillId1, exceedSkillId2, exceedSkillId3, baseSkillId, enhanceSkillGroup, enhanceSkillLevel, '

				+ ' wardrobeSlotId, equipLevelDown, '

				+ ' randomAttr1, randomValue1, '

				+ ' randomAttr2, randomValue2, '

				+ ' randomAttr3, randomValue3, '

				+ ' randomAttr4, randomValue4, '

				+ ' randomAttr5, randomValue5, '

				+ ' randomAttr6, randomValue6, '

				+ ' randomAttr7, randomValue7, '

				+ ' randomAttr8, randomValue8, '

				+ ' randomAttr9, randomValue9, '

				+ ' randomAttr10, randomValue10 '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select * from ' + _database_name + '.user_item_option with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '

	

	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21015	-- user_item_option Insert Error!!!

		GOTO item_insert_error

	end		

	

	-- user_item_polish 정보		

	_sql := 'insert into user_item_polish('

				+ ' id, name_id, random_id, polish_point'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', name_id, random_id, polish_point'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select id, name_id, random_id, polish_point from ' + _database_name + '.user_item_polish with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21016	-- user_item_polish Insert Error!!!

		GOTO item_insert_error

	end	

	

	



	-- user_item_ext 정보		

	_sql := 'insert into user_item_freeTrade('

				+ ' id, name_id, freetradestate'

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', name_id, freetradestate'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select user_item_freeTrade.id, user_item_freeTrade.name_id, user_item_freeTrade.freetradestate from ' + _database_name + '.user_item_freeTrade with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -11043	-- user_item_ext Insert Error!!!

		GOTO item_insert_error

	end		





	_sql := 'insert into user_item_attribute('

				+ ' id, attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ') '

				+ ' select '

				+ cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ '''select '

				+ + cast(_tmp_item_new_id as nvarchar) + ', attribute1, attribute1value, attribute2, attribute2value, attribute3, attribute3value, attribute4, attribute4value, attribute5, attribute5value, attribute6, attribute6value from ' + _database_name + '.user_item_attribute with (nolock) where id = ' + cast(_tmp_item_id as nvarchar) + ''') as f '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -21017	-- user_item_attribute Insert Error!!!

		GOTO item_insert_error

	end

	

	

	_sql := 'insert into user_disassembly_retry('

				+ ' charId, ItemId, retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ') '

				+ ' select '

				+ cast(_char_id as nvarchar) + ', ' + cast(_tmp_item_new_id as nvarchar) + ', retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate '

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ ' ''select * from ' + _database_name + '.user_disassembly_retry with (nolock) where ItemId = ' + cast(_tmp_item_id as nvarchar) + ''') '



	--PRINT N'query run :' + _sql

	exec (_sql)



	if @_error <> 0	

	begin 

		_ret := -12013	-- user_disassembly_retry Error!!!

		GOTO item_insert_error

	end

	



	fetch next from tmpItem_cursor into _tmp_item_id, _tmp_warehouse

end



item_insert_error:

close tmpItem_cursor

deallocate tmpItem_cursor

drop table #temp_user_item



if _ret <> 0	GOTO error_process



-- Mail 이전...

-- from_id 는 0 으로 Setting 된다.

_sql := 'insert into user_mail ('

			+ ' to_id, to_name,'

			+ ' from_id, from_name, title, content,'

			+ ' item_id, item_nameid, item_amount, money, state, arrive_time, express_mail, item_tid, abyss_point '

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', to_name,'

			+ ' 0, from_name, title, content, ' 

			+ ' COALESCE(new_item.new_id, 0), item_nameid, item_amount, money, state, arrive_time, express_mail, item_tid, abyss_point '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select * from ' + _database_name + '.user_mail with (nolock) where to_id = ' + cast(_from_char_id as nvarchar) + ' '') as org '

			+ ' left join temp_item_index_change_info as new_item on new_item.old_id = org.item_id'



--PRINT N'query run :' + _sql

exec (_sql)





if @_error <> 0	

begin 

	_ret := -11009	-- Mail Insert Error!!!

	GOTO error_process

end







-- vendor item 삭제

_sql := ' delete '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select * from ' + _database_name + '.vendor_item_light where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



-- PRINT N'query run :' + _sql

exec (_sql)



if @_error <> 0	

begin 

	_ret := -11049	-- Mail Insert Error!!!

	GOTO error_process

end



-- vendor item 삭제

_sql := ' delete '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select * from ' + _database_name + '.vendor_item_dark where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



-- PRINT N'query run :' + _sql

exec (_sql)



if @_error <> 0	

begin 

	_ret := -11050	-- vendor DELETE FROM Error!!!

	GOTO error_process

end





declare _sum_sold_price bigint

_sum_sold_price := 0



_sql := ' select _sum_sold_price = _sum_sold_price + CAST(COALESCE(SUM(sold_price - after_fee), 0) AS bigint) '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select sold_price, after_fee from ' + _database_name + '.vendor_log_dark with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') as org '



--PRINT N'query run :' + _sql

exec sp_executesql _sql, N'_sum_sold_price bigint output', _sum_sold_price output



_sql := ' select _sum_sold_price = _sum_sold_price + CAST(COALESCE(SUM(sold_price - after_fee), 0) AS bigint) '

			+ 'from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select sold_price, after_fee from ' + _database_name + '.vendor_log_light with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') as org '



--PRINT N'query run :' + _sql

exec sp_executesql _sql, N'_sum_sold_price bigint output', _sum_sold_price output



if  _sum_sold_price > 0

begin

	--print N'vendor log send mail (sum_sold_price)' + cast(_sum_sold_price as nvarchar)

	exec aion_MailWrite _char_id, _char_name, 0, '$$SVR_MOVE_TRADER', '$$SVR_MOVE_TRADE_MAIL_TITLE', '$$SVR_MOVE_TRADE_MAIL_BODY', 0, 0, 0, _sum_sold_price/*money*/, 5/*warehouse*/, _delete_date, 0

end





declare _sum_warehouse_qina bigint

_sum_warehouse_qina := 0





if _with_account_warehouse > 0		-- 계정창고 이전 조건인 경우만 이전

begin



	select _sum_warehouse_qina = COALESCE(SUM(amount), 0)

	from user_item

	where warehouse = 6 and char_id = _account_id and name_id = 182400001

	

	delete from user_item

	where warehouse = 6 and char_id = _account_id and name_id = 182400001 and id not in (SELECT id from user_item as b where warehouse = 6 and char_id = _account_id and name_id = 182400001)

	

	update user_item set amount = _sum_warehouse_qina where warehouse= 6 and char_id = _account_id and name_id = 182400001

	

	

	select _sum_warehouse_qina = COALESCE(SUM(amount), 0)

	from user_item

	where warehouse = 7 and char_id = _account_id and name_id = 182400001

	

	delete from user_item

	where warehouse = 7 and char_id = _account_id and name_id = 182400001 and id not in (select top 1 id from user_item as b where warehouse = 7 and char_id = _account_id and name_id = 182400001)

	

	update user_item set amount = _sum_warehouse_qina where warehouse = 7 and char_id = _account_id and name_id = 182400001

	

	

	

end



/*

update user_item

set  amount = COALESCE(amount, 0) + _sum_sold_price

where char_id = _from_char_id and name_id = 182400001



if @_error <> 0	

begin 

	_ret := -11051	-- vendor qina return!!!

	GOTO error_process

end



if @_r_o_w_c_o_u_n_t = 0

begin

	INSERT user_item (char_id, name_id, slot_id, amount, tid, slot, warehouse,

			producer, expired_time,buy_amount, buy_duration, main_item_dbid)

	values(_char_id, 182400001, -1, _sum_sold_price, 0,0,0,

			0, 0, 0, 0,	0)

			

	if @_error <> 0	

	begin 

		_ret := -11052	-- vendor qina return!!!

		GOTO error_process

	end			

end

*/



-- Abnormal Status 이전

_sql := 'INSERT INTO user_abnormal_status ('

			+ ' char_id, skill_id, skill_level, target_slot,'

			+ ' effect_remain1, effect_remain2, effect_remain3, effect_remain4,'

			+ ' interval_value1, interval_value2, interval_value3, interval_value4'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', skill_id, skill_level, target_slot,'

			+ ' effect_remain1, effect_remain2, effect_remain3, effect_remain4,'

			+ ' interval_value1, interval_value2, interval_value3, interval_value4'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_abnormal_status with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11010	-- Abnormal Status Insert Error!!!

	GOTO error_process

end



-- Change Log 이전

_sql := 'INSERT INTO user_change_log ('

			+ ' char_id, change_type, race, class, lev, old_value, new_value, change_time, playtime, intervaltime'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', change_type, race, class, lev, old_value, new_value, change_time, playtime, intervaltime'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_change_log with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11011	-- Change Log Insert Error!!!

	GOTO error_process

end



-- client setting 이전

_sql := 'INSERT INTO user_client_settings ('

			+ ' char_id, data_size, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', data_size, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_client_settings with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11012	-- client setting Insert Error!!!

	GOTO error_process

end



-- client quickbar setting 이전

_sql := 'INSERT INTO user_client_quickbar ('

			+ ' char_id, data_size, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', data_size, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_client_quickbar with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11013	-- client setting Insert Error!!!

	GOTO error_process

end











-- Emotion 이전

_sql := 'INSERT INTO user_emotion ('

			+ ' char_id, emotion_type, expire_date'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', emotion_type, expire_date'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_emotion with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)



if @_error <> 0	

begin 

	_ret := -11014	-- Emotion Insert Error!!!

	GOTO error_process

end



-- Finished Quest 이전

_sql := 'INSERT INTO user_finished_quest ('

			+ ' char_id, quest_id, quest_count, quest_branch, repeat_quest_count, repeat_quest_resetnum '

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', quest_id, quest_count, quest_branch, repeat_quest_count, repeat_quest_resetnum '

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_finished_quest with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11015	-- Finished Quest Insert Error!!!

	GOTO error_process

end



-- Item cooltime 이전

_sql := 'INSERT INTO user_item_cooltime ('

			+ ' char_id, cooltime_data_cnt, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', cooltime_data_cnt, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_item_cooltime with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11016	-- Item cooltime Insert Error!!!

	GOTO error_process

end



-- Macro 이전

_sql := 'INSERT INTO user_macro ('

			+ ' char_id, slot_id, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', slot_id, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_macro with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11017	-- Macro Insert Error!!!

	GOTO error_process

end



-- Promotion cooltime 이전

_sql := 'INSERT INTO user_promotion_cooltime ('

			+ ' char_id, promotion_id, last_promotion_time, cycle_received_item_count, cycle_next_reset_time '

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', promotion_id, last_promotion_time, cycle_received_item_count, cycle_next_reset_time '

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_promotion_cooltime with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11018	-- Promotion cooltime Insert Error!!!

	GOTO error_process

end





-- Quest 이전

_sql := 'INSERT INTO user_quest ('

			+ ' char_id, quest_id, quest_status, quest_progress, quest_branch'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', quest_id, quest_status, quest_progress, quest_branch'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_quest with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11019	-- Quest Insert Error!!!

	GOTO error_process

end



-- Recipe 이전

_sql := 'INSERT INTO user_recipe ('

			+ ' char_id, recipe_id, remain_count'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', recipe_id, remain_count'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_recipe with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11020	-- Recipe Insert Error!!!

	GOTO error_process

end



-- Skill 이전

_sql := 'INSERT INTO user_skill ('

			+ ' char_id, skill_id, skill_data1, skill_data2'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', skill_id, skill_data1, skill_data2'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_skill with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11021	-- Skill Insert Error!!!

	GOTO error_process

end



-- Skill cooltime 이전

_sql := 'INSERT INTO user_skill_cooltime ('

			+ ' char_id, cooltime_data_cnt, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', cooltime_data_cnt, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_skill_cooltime with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11022	-- Skill cooltime Insert Error!!!

	GOTO error_process

end



-- client favorite setting 이전

_sql := 'INSERT INTO user_client_favorite ('

			+ ' char_id, data_size, data'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', data_size, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_client_favorite with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11023	-- client setting Insert Error!!!

	GOTO error_process

end





-- user_bm_pack 이전

_sql := 'INSERT INTO user_bm_pack ('

			+ ' char_id, pack_type, pack_state, expiration_time, unique_param'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', pack_type, pack_state, expiration_time, unique_param'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_bm_pack with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11024	-- client setting Insert Error!!!

	GOTO error_process

end





-- user_dportal 이전

_sql := 'INSERT INTO user_dportal ('

			+ ' char_id, dpId, lastdp_world, lastdp_xlocation, lastdp_ylocation, lastdp_zlocation'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', dpId, lastdp_world, lastdp_xlocation, lastdp_ylocation, lastdp_zlocation'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_dportal with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11025	-- client setting Insert Error!!!

	GOTO error_process

end





-- user inter_buddy 이전

_sql := 'INSERT INTO user_buddy_inter ('

			+ ' char_id, buddy_id, delete_flag, buddy_name, server_id, comment '

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', buddy_id, delete_flag, buddy_name, server_id, comment '

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_buddy_inter with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11028	-- client setting Insert Error!!!

	GOTO error_process

end





-- inter buddy old character 입력 실패

_sql := 'INSERT INTO user_old_character ('

			+ ' char_id, old_char_id, old_server_id, old_char_name '

			+ ') '

			+ ' VALUES ( '

			+ ' ' + cast(_char_id as nvarchar) + ', ' + cast(_from_char_id as nvarchar) + ', ' + cast(_from_server as nvarchar) + ', ''' + _from_char_name + ''' ' 

			+ ' ) '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11029	-- client setting Insert Error!!!

	GOTO error_process

end







-- user_customAnimation 관련

_sql := 'insert into user_customAnimation('

			+ ' char_id, animation_id, animation_type, useState, expire_time'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', animation_id, animation_type, useState, expire_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select * from ' + _database_name + '.user_customAnimation with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') as f '



exec (_sql)

--PRINT N'query run :' + _sql



if @_error <> 0	

begin 

	_ret := -21002	-- user_customAnimation Insert Error!!!

	GOTO error_process

end	





-- user_customize_history 

_sql := 'insert into user_customize_history('

+ ' char_id, '

+ ' user_id, '

+ ' account_id, '

+ ' account_name, '

+ ' race, '

+ ' class, '

+ ' gender, '

+ ' lev, '

+ ' history_date, '

+ ' head_face_color, '

+ ' head_hair_color, '

+ ' head_eye_color, '

+ ' head_lip_color, '

+ ' head_face_type, '

+ ' head_hair_type, '

+ ' height_scale, '

+ ' head_voice_type, '

+ ' head_feat_type1, '

+ ' head_feat_type2, '

+ ' feat_version, '

+ ' feat_face_shape, '

+ ' feat_forehead_shape, '

+ ' feat_eye_position, '

+ ' feat_eye_glabella, '

+ ' feat_eye_length, '

+ ' feat_eye_height, '

+ ' feat_eye_shape, '

+ ' feat_eye_tail, '

+ ' feat_eyeblow_pos, '

+ ' feat_eyeblow_angle, '

+ ' feat_eyeblow_shape, '

+ ' feat_nose_pos, '

+ ' feat_nose_bridge, '

+ ' feat_nose_side, '

+ ' feat_nose_tip, '

+ ' feat_cheek_shape, '

+ ' feat_mouth_pos, '

+ ' feat_mouth_size, '

+ ' feat_lip_thickness, '

+ ' feat_lip_tail, '

+ ' feat_lip_shape, '

+ ' feat_jaw_pos, '

+ ' feat_jaw_shape, '

+ ' feat_head_size, '

+ ' feat_neck_thickness, '

+ ' feat_neck_length, '

+ ' feat_shoulder_size, '

+ ' feat_upper_size, '

+ ' feat_waist_size, '

+ ' feat_hip_size, '

+ ' feat_arm_thickness, '

+ ' feat_leg_thickness, '

+ ' feat_foot_size, '

+ ' feat_ear_shape, '

+ ' feat_face_ratio, '

+ ' feat_wing_size, '

+ ' feat_arm_length, '

+ ' feat_leg_length, '

+ ' feat_shoulder_width, '

+ ' head_bump_type, '

+ ' head_expression_type, '

+ ' feat_head_figure, '

+ ' head_eye_type, '

+ ' head_dark_tail, '

+ ' head_eye_color2, '

+ ' head_eye_lash, '

+ ' feat_head_eye_size, '

+ ' feat_upper_height, '

+ ' feat_arm_lower_thickness, '

+ ' feat_hand_length, '

+ ' feat_leg_lower_thickness '

+ ') '

+ ' select '

+ ' ' + cast(_char_id as nvarchar) + ', '

+ ' f.user_id, '

+ ' f.account_id, '

+ ' f.account_name, '

+ ' f.race, '

+ ' f.class, '

+ ' f.gender, '

+ ' f.lev, '

+ ' f.history_date, '

+ ' f.head_face_color, '

+ ' f.head_hair_color, '

+ ' f.head_eye_color, '

+ ' f.head_lip_color, '

+ ' f.head_face_type, '

+ ' f.head_hair_type, '

+ ' f.height_scale, '

+ ' f.head_voice_type, '

+ ' f.head_feat_type1, '

+ ' f.head_feat_type2, '

+ ' f.feat_version, '

+ ' f.feat_face_shape, '

+ ' f.feat_forehead_shape, '

+ ' f.feat_eye_position, '

+ ' f.feat_eye_glabella, '

+ ' f.feat_eye_length, '

+ ' f.feat_eye_height, '

+ ' f.feat_eye_shape, '

+ ' f.feat_eye_tail, '

+ ' f.feat_eyeblow_pos, '

+ ' f.feat_eyeblow_angle, '

+ ' f.feat_eyeblow_shape, '

+ ' f.feat_nose_pos, '

+ ' f.feat_nose_bridge, '

+ ' f.feat_nose_side, '

+ ' f.feat_nose_tip, '

+ ' f.feat_cheek_shape, '

+ ' f.feat_mouth_pos, '

+ ' f.feat_mouth_size, '

+ ' f.feat_lip_thickness, '

+ ' f.feat_lip_tail, '

+ ' f.feat_lip_shape, '

+ ' f.feat_jaw_pos, '

+ ' f.feat_jaw_shape, '

+ ' f.feat_head_size, '

+ ' f.feat_neck_thickness, '

+ ' f.feat_neck_length, '

+ ' f.feat_shoulder_size, '

+ ' f.feat_upper_size, '

+ ' f.feat_waist_size, '

+ ' f.feat_hip_size, '

+ ' f.feat_arm_thickness, '

+ ' f.feat_leg_thickness, '

+ ' f.feat_foot_size, '

+ ' f.feat_ear_shape, '

+ ' f.feat_face_ratio, '

+ ' f.feat_wing_size, '

+ ' f.feat_arm_length, '

+ ' f.feat_leg_length, '

+ ' f.feat_shoulder_width, '

+ ' f.head_bump_type, '

+ ' f.head_expression_type, '

+ ' f.feat_head_figure, '

+ ' f.head_eye_type, '

+ ' f.head_dark_tail, '

+ ' f.head_eye_color2, '

+ ' f.head_eye_lash, '

+ ' f.feat_head_eye_size, '

+ ' f.feat_upper_height, '

+ ' f.feat_arm_lower_thickness, '

+ ' f.feat_hand_length, '

+ ' f.feat_leg_lower_thickness '

+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

+ '''select * from ' + _database_name + '.user_customize_history with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') as f '



exec (_sql)

--PRINT N'query run :' + _sql



if @_error <> 0	

begin 

	_ret := -21005	-- user_customize_history Insert Error!!!

	GOTO error_process

end	









-- user_wallet 관련

_sql := 'insert into user_wallet('

			+ ' char_id, name_id, item_dbid, amount, create_date, update_date'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', name_id, item_dbid, amount, create_date, update_date'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ '''select * from ' + _database_name + '.user_wallet with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ''') as f '



exec (_sql)

--PRINT N'query run :' + _sql



if @_error <> 0	

begin 

	_ret := -21003	-- user_customAnimation Insert Error!!!

	GOTO error_process

end	





-- Stat 이전

_sql := 'INSERT INTO user_stat ('

			+ ' character_id, HP, MP, DP, STR, VIT, AGI, DEX, KNO, WILL,' 

			+ ' PhysicalRight, AccuracyRight, CriticalRight, PhysicalLeft, AccuracyLeft, CriticalLeft,'

			+ ' AttackSpeed, MoveSpeed, MagicalBoost,'

			+ ' MagicalAccuracy, PhysicalDefend, Dodge, Block, Parry, MagicResist, FireResist, AirResist, WaterResist, EarthResist,'

			+ ' baseHP, baseMP, baseDP, baseSTR, baseVIT, baseAGI, baseDEX, baseKNO, baseWILL,'

			+ ' basePhysicalRight, baseAccuracyRight, baseCriticalRight, basePhysicalLeft, baseAccuracyLeft, baseCriticalLeft,'

			+ ' baseAttackSpeed, baseMoveSpeed, baseMagicalBoost,'

			+ ' baseMagicalAccuracy, basePhysicalDefend, baseDodge, baseBlock, baseParry, baseMagicResist, baseFireResist, baseAirResist, baseWaterResist, baseEarthResist,'

			+ ' castingTimeRatio,'

			+ ' magicalCriticalRight, magicalCriticalLeft, phyCriticalReduceRate, magCriticalReduceRate, phyCriticalDamageReduce, magCriticalDamageReduce, healSkillBoost,'

			+ ' baseMagicalCriticalRight, baseMagicalCriticalLeft, basePhyCriticalReduceRate, baseMagCriticalReduceRate, basePhyCriticalDamageReduce, baseMagCriticalDamageReduce, baseHealSkillBoost, '

			+ ' magicalDefend, magicalSkillBoostResist, baseMagicalDefend, baseMagicalSkillBoostResist, '

			+ ' MagicalLeft, baseMagicalLeft, baseMagicalRight, MagicalRight, mpHealSkillBoost, baseMpHealSkillBoost, json '

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', HP, MP, DP, STR, VIT, AGI, DEX, KNO, WILL,' 

			+ ' PhysicalRight, AccuracyRight, CriticalRight, PhysicalLeft, AccuracyLeft, CriticalLeft,'

			+ ' AttackSpeed, MoveSpeed, MagicalBoost,'

			+ ' MagicalAccuracy, PhysicalDefend, Dodge, Block, Parry, MagicResist, FireResist, AirResist, WaterResist, EarthResist,'

			+ ' baseHP, baseMP, baseDP, baseSTR, baseVIT, baseAGI, baseDEX, baseKNO, baseWILL,'

			+ ' basePhysicalRight, baseAccuracyRight, baseCriticalRight, basePhysicalLeft, baseAccuracyLeft, baseCriticalLeft,'

			+ ' baseAttackSpeed, baseMoveSpeed, baseMagicalBoost,'

			+ ' baseMagicalAccuracy, basePhysicalDefend, baseDodge, baseBlock, baseParry, baseMagicResist, baseFireResist, baseAirResist, baseWaterResist, baseEarthResist,'

			+ ' castingTimeRatio,'

			+ ' magicalCriticalRight, magicalCriticalLeft, phyCriticalReduceRate, magCriticalReduceRate, phyCriticalDamageReduce, magCriticalDamageReduce, healSkillBoost,'

			+ ' baseMagicalCriticalRight, baseMagicalCriticalLeft, basePhyCriticalReduceRate, baseMagCriticalReduceRate, basePhyCriticalDamageReduce, baseMagCriticalDamageReduce, baseHealSkillBoost, '

			+ ' magicalDefend, magicalSkillBoostResist, baseMagicalDefend, baseMagicalSkillBoostResist, '

			+ ' MagicalLeft, baseMagicalLeft, baseMagicalRight, MagicalRight, mpHealSkillBoost, baseMpHealSkillBoost, json '

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_stat with (nolock) where character_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11023	-- Stat Insert Error!!!

	GOTO error_process

end



-- user_title 이전

_sql := 'INSERT INTO user_title ('

			+ ' char_id, title_id, is_have, expired_time'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', title_id, is_have, expired_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_title with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '



exec (_sql)



if @_error <> 0	

begin 

	_ret := -11024	-- user_title Insert Error!!!

	GOTO error_process

end



-- user_faction_freiendship 이전

_sql := 'Insert Into user_faction_friendship ('

			+ 'char_id, faction_id, friendship, jointime, factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime, factionquest_lastfinishedtime, factionquest_finishedcount'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', faction_id, friendship, jointime, factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime, factionquest_lastfinishedtime, factionquest_finishedcount'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_faction_friendship with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11036 -- user_faction_friendship Error!!!

	GOTO error_process

end



-- user_pet 이전

_sql := 'Insert Into user_pet ('

			+ 'char_id, name_id, slot_id, name, function_data1, function_data2, create_date, visual_data_size, visual_data, function_data1_ex1, function_data1_ex2, function_data1_ex3, function_data2_ex1, function_data2_ex2, function_data2_ex3, expired_time'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', name_id, slot_id, name, function_data1, function_data2, create_date, visual_data_size, visual_data, function_data1_ex1, function_data1_ex2, function_data1_ex3, function_data2_ex1, function_data2_ex2, function_data2_ex3, expired_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_pet with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11037 -- user_pet Error!!!

	GOTO error_process

end



-- user_punishment 이전

_sql := 'Insert Into user_punishment ('

			+ 'account_id, char_id, play_block, status, punish_code, start_date, end_date, remain_minute, cancel_date, cancel_reason, punish_reason, login_id, login_nm'

			+ ') '

			+ ' select '

			+ 'account_id, ' + cast(_char_id as nvarchar) + ', play_block, status, punish_code, start_date, end_date, remain_minute, cancel_date, cancel_reason, punish_reason, login_id, login_nm'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_punishment with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' +  'and status = 0 and ((play_block = 1 and end_date > NOW()) or (play_block = 0 and Remain_Minute > 0))' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11038 -- user_punishment Error!!!

	GOTO error_process

end



-- user_instance 이전

_sql := 'Insert Into user_instance ('

			+ 'char_id, world_id, instance_id, reentrance_time, server_id, count_variate, kina_increase, item_increase, spinel_increase'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', world_id, instance_id, reentrance_time, server_id, count_variate, kina_increase, item_increase, spinel_increase'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_instance with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11047 -- user_instance Error!!!

	GOTO error_process

end



-- user_instance_achievement 이전

_sql := 'Insert Into user_instance_achievement ('

			+ 'char_id, world_id, spawn_page, version, data'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', world_id, spawn_page, version, data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_instance_achievement with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11039 -- user_instance_achievement Error!!!

	GOTO error_process

end



-- user_rate 이전

_sql := 'Insert Into user_rate ('

			+ 'char_id, rate_id, mu, sigma, update_cnt'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', rate_id, mu, sigma, update_cnt'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_rate with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11048 -- user_rate Error!!!

	GOTO error_process

end





-- user_gp_data 이전

_sql := 'Insert Into user_gp_data ('

			+ 'char_id, glory_point, ownership_bonus_gp'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', glory_point, 0'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_gp_data with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11053 -- user_gp Error!!!

	GOTO error_process

end



-- user_gp_data 이전

if _premium = 0

begin

	update user_gp_data

	set glory_point = _gp_restrict_value

	where char_id = _char_id and glory_point > _gp_restrict_value

end



if @_error <> 0

begin

	_ret := -11055 -- user_gp Error!!!

	GOTO error_process

end



-- user_data_ext 이전

_sql := 'INSERT INTO user_data_ext ('

			+ ' char_id, creativity_point, usecp_resetcount, next_usecp_resetcount_dec_time, familiar_func_expireTime, familiar_energy, familiar_energy_autocharge, familiar_func_autocharge, last_transform_id, last_transform_scroll_id, last_summon_familiar'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', creativity_point, usecp_resetcount, next_usecp_resetcount_dec_time, familiar_func_expireTime, familiar_energy, familiar_energy_autocharge, familiar_func_autocharge, last_transform_id, last_transform_scroll_id, last_summon_familiar'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_data_ext with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12021	-- user_data_ext Insert Error!!!

	GOTO error_process

end



-- user_use_cp 이전

_sql := 'INSERT INTO user_use_cp ('

			+ ' char_id, category, enchant_object_id, value, accumulated_cp, data_id'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', category, enchant_object_id, value, accumulated_cp, data_id'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_use_cp with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12022	-- user_use_cp Insert Error!!!

	GOTO error_process

end



-- user_luna_price 이전

_sql := 'INSERT INTO user_luna_price ('

			+ ' char_id, luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time, update_time'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time, update_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_luna_price with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12023	-- user_luna_price Insert Error!!!

	GOTO error_process

end



-- user_luna_abyss_boost 이전

_sql := 'INSERT INTO user_luna_abyss_boost ('

			+ ' char_id, abyss_id, is_boost_on'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', abyss_id, is_boost_on'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_luna_abyss_boost with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12024	-- user_luna_abyss_boost Insert Error!!!

	GOTO error_process

end



-- user_wardrobe 이전

_sql := 'INSERT INTO user_wardrobe ('

			+ ' char_id, slot_id, name_id'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', slot_id, name_id'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_wardrobe with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12025	-- user_wardrobe Insert Error!!!

	GOTO error_process

end



-- user_skill_skin 이전

_sql := 'INSERT INTO user_skill_skin ('

			+ ' char_id, skill_skin_id, expire_time, use_skin, update_time'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', skill_skin_id, expire_time, use_skin, update_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_skill_skin with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12026	-- user_skill_skin Insert Error!!!

	GOTO error_process

end



-- user_rank 이전

_sql := 'INSERT INTO user_rank ('

			+ ' char_id, rank_id, point, global_ranking, global_old_ranking, local_ranking, local_old_ranking, last_ranking, last_point, best_ranking, best_point'

			+ ') '

			+ ' select '

			+ ' ' + cast(_char_id as nvarchar) + ', rank_id, point, global_ranking, global_old_ranking, 0, 0, last_ranking, last_point, best_ranking, best_point'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_rank with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

exec (_sql)

if @_error <> 0	

begin 

	_ret := -12027	-- user_rank Insert Error!!!

	GOTO error_process

end



-- user_monster_achievement 이전

_sql := 'Insert Into user_monster_achievement ('

			+ 'char_id, achieve_id, achieved_count, achieved_grade, reward_received'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', achieve_id, achieved_count, achieved_grade, reward_received'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_monster_achievement with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -12028 -- Error!!!

	GOTO error_process

end



-- user_equipment_change_flag 이전

_sql := 'Insert Into user_equipment_change_flag ('

			+ 'char_id, set_id, option_flags'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', set_id, option_flags'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_equipment_change_flag with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -12029 -- Error!!!

	GOTO error_process

end



-- user_familiar 이전

_sql := 'Insert Into user_familiar ('

			+ 'char_id, base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_familiar with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -12030 -- Error!!!

	GOTO error_process

end



-- user_extra_info 이전

_sql := 'Insert Into user_extra_info ('

			+ 'char_id, use_bot_channel, use_bot_channel_update_date, account_id, vip_icon, prevSeasonReward, currentSeasonReward'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', use_bot_channel, use_bot_channel_update_date, account_id, vip_icon, prevSeasonReward, currentSeasonReward'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_extra_info with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -12031 -- Error!!!

	GOTO error_process

end





-- house_instant 이전 실패

_sql := 'Insert Into house_instant ('

			+ 'id, state, permission, inwall, infloor, update_time, created_time'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', state, permission, inwall, infloor, update_time, created_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.house_instant with (nolock) where id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11040 -- house_instant Error!!!

	GOTO error_process

end





-- house_instant_script 이전 실패

_sql := 'Insert Into house_instant_script ('

			+ 'char_id, slot_id, script_size, script_data'

			+ ') '

			+ ' select '

			+ '' + cast(_char_id as nvarchar) + ', slot_id, script_size, script_data'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.house_instant_script with (nolock) where char_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11045 -- house_instant_script Error!!!

	GOTO error_process

end



CREATE TABLE #temp_house_object

(

	id int NOT NULL,

	object_nameid int NOT NULL,

	object_type tinyint NOT NULL,

	owner_id int NOT NULL,

	owner_type tinyint NOT NULL,

	state tinyint NOT NULL,

	expired_time int NULL,

	general_use_count int NULL,

	world int NULL,

	xlocation real NULL,

	ylocation real NULL,

	zlocation real NULL,

	dir smallint NULL,

	update_time datetime NOT NULL,

	created_time datetime NOT NULL,

	dye_info int NULL, 

	expire_dye_time int NULL

)



-- houseobject 이전 실패

_sql := 'Insert Into #temp_house_object ('

			+ 'id, owner_id, object_nameid, object_type, owner_type, state, expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir, update_time, created_time, dye_info, expire_dye_time'

			+ ') '

			+ ' select '

			+ 'id ,' + cast(_char_id as nvarchar) + ', object_nameid, object_type, owner_type, state, expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir, update_time, created_time, dye_info, expire_dye_time'

			+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.houseobject with (nolock) where owner_id = ' + cast(_from_char_id as nvarchar) + ' ' + ' '') '

exec (_sql)

if @_error <> 0

begin

	_ret := -11041 -- houseobject Error!!!

	GOTO error_process

end





declare _tmp_house_object_id bigint

declare _tmp_house_object_new_id bigint



declare tmpHouse_cursor cursor for

select id from #temp_house_object (nolock)



open tmpHouse_cursor 

fetch next from tmpHouse_cursor into _tmp_house_object_id



while @_fetch_status = 0

begin

	-- 우선 houseobject의 id 가 자동증가가 아니라 id를 구한다.  이 부분은 수정하기로 하였으므로 차후 삭제해야 한다.

	-- 아래 _tmp_house_object_new_id를 identity로 구하는 것은 주석해지 필요

	-- select _tmp_house_object_new_id = MAX(id)+1 from houseobject

	



	--PRINT N'query run : Insert House'

	_tmp_house_object_new_id := 0

	insert into houseobject (

			owner_id, object_nameid, object_type, owner_type, state, expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir, update_time, created_time, dye_info, expire_dye_time

			) 

			select 

			owner_id, object_nameid, object_type, owner_type, state, expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir, update_time, created_time, dye_info, expire_dye_time

			from #temp_house_object (nolock)

			where id = _tmp_house_object_id



	if @_error <> 0

	begin

		_ret := -11042	-- House Insert TmpTable Error!!!

		GOTO house_object_insert_error

	end



	_tmp_house_object_new_id := @_i_d_e_n_t_i_t_y

	

	

	-- houseobject_extdata 이전 실패

	_sql := 'Insert Into houseobject_extdata ('

				+ ' obj_id, char_id, accumulated_usecount, next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day'

				+ ') '

				+ ' select '

				+ cast(_tmp_house_object_new_id as nvarchar) + ', ' + cast(_char_id as nvarchar) + ', accumulated_usecount, next_resettime_for_owner, resource_id, account_id, cur_owner_usecnt_per_day'

				+ ' from openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ ' ''select * from ' + _database_name + '.houseobject_extdata with (nolock) where obj_id = ' + cast(_tmp_house_object_id as nvarchar) + ' ' + ' '') '

	exec (_sql)

	if @_error <> 0

	begin

		_ret := -11044 -- houseobject_extdata Error!!!

		GOTO house_object_insert_error

	end	

	

	fetch next from tmpHouse_cursor into _tmp_house_object_id

end

house_object_insert_error:

close tmpHouse_cursor

deallocate tmpHouse_cursor

truncate table #temp_house_object

if _ret <> 0	GOTO error_process





declare _check_use_org_char_name int

exec _check_use_org_char_name = aion_CheckValidCharName _from_char_name_real, ''

if @_error <> 0

begin 

	_ret := -11031	-- 원래 이름으로 변경

	GOTO error_process

end



if _check_use_org_char_name = 0

begin

	update user_data set user_id = _from_char_name_real 

	where char_id = _char_id

	

	if @_error <> 0	or @_rowcount = 0 

	begin 

		_ret := -11025	-- 원래 이름으로 변경

		GOTO error_process

	end

end

else

begin

	--PRINT 'user org: ' + convert(nvarchar,_check_use_org_char_name,3 ) + ', ' + _from_char_name_real



	-- 캐릭터 Temp이름 변경 Log 만들기

	insert into user_name_change_log (char_id, old_name, new_name, change_date, item_id, tid,

					account_id, account_name, race, class, gender, lev)

	select char_id, _from_char_name_real, user_id, NOW(), 0, 0, 

					account_id, account_name, race, class, gender, lev

	from user_data with (nolock) 

	where char_id = _char_id



	if @_error <> 0	or @_rowcount = 0

	begin 

		_ret := -11026	-- char name change log error!!!

		GOTO error_process

	end



	INSERT user_item (char_id, name_id, slot_id, amount, tid, slot, warehouse,

			producer, expired_time,buy_amount, buy_duration, main_item_dbid)

	values(_char_id, 169670001, -1, 1, 0,0,0,

			0, 0, 0, 0,	0)



	if @_error <> 0	or @_rowcount = 0

	begin 

		_ret := -11027	-- give char name change item error!!!

		GOTO error_process

	end



end



/* bighouse:외모 변경권 지급 삭제, 혹시 언젠가 다른 아이템 지급할지 모르니 주석처리 함.

if _premium > 0 and (_from_server <> 63 and _from_server <> 64)

begin

	INSERT user_item (char_id, name_id, slot_id, amount, tid, slot, warehouse,

			producer, expired_time,buy_amount, buy_duration, main_item_dbid)

	values(_char_id, 188051759, -1, 1, 0,0,5,

			0, 0, 0, 0,	0)

	

	if @_error <> 0	or @_rowcount = 0

	begin 

		_ret := -11027	

		GOTO error_process

	end			



	exec aion_MailWrite _char_id, _char_name, 0, '$$SVR_MOVE_SUCCESS', '$$SVR_MOVE_SUCCESS_TITLE', '$$SVR_MOVE_SUCCESS_BODY', @_i_d_e_n_t_i_t_y, 188051759, 0, 0/*money*/, 0/*warehouse*/, 0, 1

end

*/



-- Org Server에 1년간 이름 사용금지 처리

_sql := 'INSERT INTO '

			+ ' openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select ' 

			+ 'FORBIDDEN_TYPE, FORBIDDEN_REASON, WORLD_ID, '

			+ 'FORBIDDEN_CHAR, FORBIDDEN_ACCOUNT_NM, '

			+ 'STATUS, LOGIN_ID, LOGIN_NM, REGDATE '

			+ 'from ' + _database_name + '.forbidden_char '' '

			+ ') '

			+ '	values(1, 3, ' + cast(_from_server as nvarchar) + ', ''' + _from_char_name_real + ''', '''', 0, ''AddedService'', ''Type4_MoveServer'', NOW())'



exec (_sql)



if @_error <> 0	or @_rowcount = 0

begin 

	_ret := -11029

	GOTO error_process

end



-- Org Server의 캐릭터 삭제 처리

_sql := 'update '

			+ ' openrowset (''SQLOLEDB'', ' + _db_info + ','

			+ ' ''select * from ' + _database_name + '.user_data where char_id = ' + cast(_from_char_id as nvarchar) + ' '') '

			+ ' set delete_date = ' + cast(_delete_date as nvarchar) + ', '

			+ ' delete_complete_date = ' + cast(_delete_date as nvarchar) + ', '

			+ ' change_info_time	= ' + cast(_delete_date as nvarchar) + ', '

			+ ' delete_type	= ' + cast(_server as nvarchar) + ' '



exec (_sql)



if @_error <> 0	or @_rowcount = 0

begin

	_ret := -11030

	goto error_process

end



if _ret <> 0	GOTO error_process





--  계정창고 아이템 삭제 처리

if _with_account_warehouse > 0		-- 계정창고 이전 조건인 경우만 삭제

begin	

	_sql := 'update '

				+ ' openrowset (''SQLOLEDB'', ' + _db_info + ','

				+ ' ''select * from ' + _database_name + '.user_item where warehouse in (6,7) and char_id = ' + cast(_account_id as nvarchar) + ' '') '

				+ ' set warehouse = 10, char_id = ' + cast(_from_char_id as nvarchar)
RAISE NOTICE '%', (_sql) /* LIMIT 1 appended */ LIMIT 1;

	exec (_sql)



	if @_error <> 0

	begin

		_ret := -12001

		goto error_process

	end

end



if _ret <> 0	GOTO error_process



--select * into temp_svr_move from temp_item_index_change_info



--drop table temp_item_index_change_info

return

-- 여기까지 정상 종료





error_process:

--drop table temp_item_index_change_info



if _char_id <> 0

begin

	delete from user_name_change_log where char_id = _char_id

	delete from user_title where char_id = _char_id

	delete from user_stat where character_id = _char_id

	delete from user_skill_cooltime where char_id = _char_id

	delete from user_skill where char_id = _char_id

	delete from user_recipe where char_id = _char_id

	delete from user_quest where char_id = _char_id

	delete from user_promotion_cooltime where char_id = _char_id

	delete from user_macro where char_id = _char_id

	delete from user_item_cooltime where char_id = _char_id

	delete from user_item_sealed where char_id = _char_id

	delete from user_item_ext where char_id = _char_id

	delete from user_finished_quest where char_id = _char_id

	delete from user_emotion where char_id = _char_id

	delete from user_client_settings where char_id = _char_id

	delete from user_client_quickbar where char_id = _char_id

	delete from user_change_log where char_id = _char_id

	delete from user_abnormal_status where char_id = _char_id



	delete from vendor_log_light where char_id = _char_id

	delete from vendor_log_dark where char_id = _char_id

	delete from vendor_item_light where char_id = _char_id

	delete from vendor_item_dark where char_id = _char_id



	delete from user_faction_friendship where char_id = _char_id

	delete from user_mail where to_id = _char_id

	delete from user_item where char_id = _char_id

	if _with_account_warehouse > 0		-- 계정창고 이전 조건인 경우만 삭제, 정상적으로 롤백이 힘듬..

	begin	

		delete from user_item where char_id = _account_id and warehouse in (6,7)

	end

	delete from user_pet where char_id = _char_id

	

	delete from user_punishment where char_id = _char_id

	delete from user_instance where char_id = _char_id

	delete from user_instance_achievement where char_id = _char_id

	

	delete from house_instant where id = _char_id

	delete from house_instant_script where char_id = _char_id

	delete from houseobject_extdata where char_id = _char_id

	delete from houseobject where owner_id = _char_id



	delete from user_move_service_log where char_id = _char_id

	delete from user_data where char_id = _char_id

end



if _char_id <> 0

begin

	-- 원래 존재했던 캐릭터 복원

	update user_data 

		set delete_date = 0, delete_complete_date = 0, delete_type = 0

		where char_id = _char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_process_ors;
-- +goose StatementEnd
