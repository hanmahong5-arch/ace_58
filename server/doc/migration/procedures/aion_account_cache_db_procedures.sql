-- ============================================================
-- PL/pgSQL Functions converted from AionAccountCacheDB
-- Source: AionAccountCacheDB_schema.json
-- Total: 101 procedures
-- Auto-converted: 100
-- Needs review: 1
-- Needs manual work: 0
-- ============================================================

-- Confidence Legend:
--   [AUTO]   - Fully automatic conversion
--   [REVIEW] - Likely correct, please verify
--   [MANUAL] - Needs human intervention

-- [OK] [AUTO] aion_ConfirmLunaReward

CREATE OR REPLACE FUNCTION aion_confirmlunareward(
    p_accountId integer,
    p_keyCount integer,
    p_decrease integer,
    p_remain integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentRemain integer;
    v_currentKey integer;
    v_curdate timestamp;
BEGIN
    v_currentKey := 0;
    v_currentRemain := 0;
    v_curdate := (CAST(TO_CHAR(CAST(CURRENT_TIMESTAMP + INTERVAL '9 hours' AS date), 'YYYYMMDD') AS integer));
    IF v_curdate > CURRENT_TIMESTAMP THEN
    v_curdate := (v_curdate + INTERVAL '-1 days');
    END IF;
    SELECT remain_reward, key_count INTO v_currentRemain, v_currentKey FROM account_luna_reward where accountId = p_accountId and updatedate >= v_curdate;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount <=0 THEN
    RETURN -3;
    END IF;
    IF (v_currentRemain <> p_remain) THEN
    RETURN -1;
    END IF;
    IF (v_currentRemain - p_decrease) > 0 THEN
    RETURN -2;
    END IF;
    update account_luna_reward set key_count = key_Count + p_keyCount, remain_reward = p_decrease where accountId = p_accountId;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_DecreaseLunaKey

CREATE OR REPLACE FUNCTION aion_decreaselunakey(
    p_accountId integer,
    p_decreaseKey integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentKey integer;
BEGIN
    IF p_decreaseKey < 0 THEN
    RETURN -1;
    END IF;
    v_currentKey := 0;
    -- Transaction managed by PG function context
    SELECT key_count INTO v_currentKey FROM account_luna_reward where accountId = p_accountId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    -- COMMIT (implicit in PG function)
    RETURN -2;
    ELSE
    IF v_currentKey + p_decreaseKey < 0 THEN
    -- COMMIT (implicit in PG function)
    RETURN -3;
    END IF;
    update account_luna_reward set key_count = key_count - p_decreaseKey, updatedate = CURRENT_TIMESTAMP where accountId = p_accountId;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_DeleteLoginEventInfo

CREATE OR REPLACE FUNCTION aion_deletelogineventinfo(
    p_account_id integer,
    p_event_id integer,
    p_days integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF (p_account_id = 0 and p_event_id = 0) THEN
    DELETE FROM user_login_event_data_daily WHERE be_rewarded <> 1 and (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (recent_count_update_date)::timestamp) / 86400)::integer >= p_days;
    DELETE FROM user_login_event_data_other WHERE be_rewarded <> 1 and (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (recent_count_update_date)::timestamp) / 86400)::integer >= p_days;
    ELSE
    DELETE FROM user_login_event_data_daily WHERE account_id = p_account_id::integer and event_id = p_event_id and (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (recent_count_update_date)::timestamp) / 86400)::integer >= p_days;
    DELETE FROM user_login_event_data_other WHERE account_id = p_account_id::integer and event_id = p_event_id and (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (recent_count_update_date)::timestamp) / 86400)::integer >= p_days;
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_DeletePromotionCoolTimeForAC

CREATE OR REPLACE FUNCTION aion_deletepromotioncooltimeforac(
    p_nAccountId integer,
    p_nPromotionId smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM user_promotion_cooltime WHERE account_id = p_nAccountId::integer and promotion_id=p_nPromotionId;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_DeleteUserInfo_20120703

CREATE OR REPLACE FUNCTION aion_deleteuserinfo_20120703(
    p_char_id integer,
    p_server_id integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_utc_adjust bigint;
BEGIN
    delete from global_user_data WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetAccountData

CREATE OR REPLACE FUNCTION aion_getaccountdata(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT hidden_fatigue_point, hidden_fatigue_updatetime from account_data WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetAccountData_20151117

CREATE OR REPLACE FUNCTION aion_getaccountdata_20151117(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT hidden_fatigue_point, hidden_fatigue_updatetime, COALESCE(hidden_fatigue_npckill,0) from account_data WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetAccountData_20170428

CREATE OR REPLACE FUNCTION aion_getaccountdata_20170428(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT hidden_fatigue_point, hidden_fatigue_updatetime, COALESCE(hidden_fatigue_npckill, 0), limit_play_reset_time, limit_play_accum_time from account_data WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetAccountPackList

CREATE OR REPLACE FUNCTION aion_getaccountpacklist(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT pack_type, expire_date from account_pack where account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetBoardBMInfo

CREATE OR REPLACE FUNCTION aion_getboardbminfo(
    p_accountId integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_maxLevAmongNormalServers integer;
    v_maxLevAmongSpecialServers integer;
BEGIN
    SELECT MAX(user_level) INTO v_maxLevAmongNormalServers FROM global_user_data where account_id = p_accountId::integer and is_special_server = 0 and delete_date = 0 group by account_id;
    SELECT MAX(user_level) INTO v_maxLevAmongSpecialServers FROM global_user_data where account_id = p_accountId::integer and is_special_server != 0 and delete_date = 0 group by account_id;
    PERFORM game_id, current_pos, visited_pos, last_freecharge_time, last_reset_time, free_dice_remain, paid_dice_remain, paid_reset_remain, COALESCE(v_maxLevAmongNormalServers, 0), COALESCE(v_maxLevAmongSpecialServers, 0) FROM user_board_bm WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetBoardBMInfo_2017

CREATE OR REPLACE FUNCTION aion_getboardbminfo_2017(
    p_accountId integer,
    p_isSpecial integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_maxLevAmongNormalServers integer;
    v_maxLevAmongSpecialServers integer;
    v_last_freecharge_time bigint;
    v_free_dice_remain integer;
    v_paid_dice_remain integer;
    v_paid_reset_remain integer;
    v_game_id integer;
    v_current_pos integer;
    v_visited_pos integer;
    v_last_reset_time bigint;
BEGIN
    SELECT MAX(user_level) INTO v_maxLevAmongNormalServers FROM global_user_data where account_id = p_accountId::integer and is_special_server = 0 and delete_date = 0 group by account_id;
    SELECT MAX(user_level) INTO v_maxLevAmongSpecialServers FROM global_user_data where account_id = p_accountId::integer and is_special_server != 0 and delete_date = 0 group by account_id;
    SELECT last_freecharge_time, free_dice_remain, paid_dice_remain, paid_reset_remain INTO v_last_freecharge_time, v_free_dice_remain, v_paid_dice_remain, v_paid_reset_remain FROM user_board_bm_dice WHERE account_id = p_accountId::integer;
    SELECT game_id, current_pos, visited_pos, last_reset_time INTO v_game_id, v_current_pos, v_visited_pos, v_last_reset_time FROM user_board_bm_game WHERE account_id = p_accountId::integer and is_special_server = p_isSpecial;
    PERFORM COALESCE(v_game_id, 0), COALESCE(v_current_pos, 0), COALESCE(v_visited_pos, 0), COALESCE(v_last_reset_time, 0), COALESCE(v_last_freecharge_time, 0), COALESCE(v_free_dice_remain, 0), COALESCE(v_paid_dice_remain, 0), COALESCE(v_paid_reset_remain, 0), COALESCE(v_maxLevAmongNormalServers, 0), COALESCE(v_maxLevAmongSpecialServers, 0);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetCosmetic

CREATE OR REPLACE FUNCTION aion_getcosmetic(
    p_nCosmeticId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT account_id, server_id, char_id, race, gender, feat_version, head_face_color, head_hair_color, head_eye_color, head_lip_color, head_face_type, head_hair_type, height_scale, head_voice_type, head_feat_type1, head_feat_type2, COALESCE(head_bump_type, 0), COALESCE(head_expression_type, 0), feat_face_shape, feat_forehead_shape, feat_eye_position, feat_eye_glabella, feat_eye_length, feat_eye_height, feat_eye_shape, feat_eye_tail, feat_eyeblow_pos, feat_eyeblow_angle, feat_eyeblow_shape, feat_nose_pos, feat_nose_bridge, feat_nose_side, feat_nose_tip, feat_cheek_shape, feat_mouth_pos, feat_mouth_size, feat_lip_thickness, feat_lip_tail, feat_lip_shape, feat_jaw_pos, feat_jaw_shape, feat_ear_shape, feat_head_size, feat_neck_thickness, feat_neck_length, feat_shoulder_size, feat_upper_size, feat_bust_size, feat_waist_size, feat_hip_size, feat_arm_thickness, feat_hand_size, feat_leg_thickness, feat_foot_size, feat_face_ratio, feat_wing_size, feat_arm_length, feat_leg_length, feat_shoulder_width, COALESCE(feat_head_figure, 0) FROM cosmetic_data WHERE cosmetic_id = p_nCosmeticId;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetLastCheckTimeUserMoveSvr

CREATE OR REPLACE FUNCTION aion_getlastchecktimeusermovesvr(
    p_serverId integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_curr_time integer;
    v_last_checktime integer;
BEGIN
    v_curr_time := GetUnixtimeWithUTCAdjust((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),0);
    SELECT movesvr_last_checktime INTO v_last_checktime FROM aion_server_data where server_id = p_serverId::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_last_checktime := v_curr_time;
    INSERT INTO aion_server_data(server_id, movesvr_last_checktime) values (p_serverId, v_curr_time);
    ELSE
    update aion_server_data set movesvr_last_checktime = v_last_checktime where server_id = p_serverId::integer;
    END IF;
    RETURN v_last_checktime;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetLoginEventInfo

CREATE OR REPLACE FUNCTION aion_getlogineventinfo(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT event_id, valid_login_count, recent_count_update_date, be_rewarded FROM user_login_event_data_daily WHERE account_id = p_accountId::integer UNION SELECT event_id, valid_login_count, recent_count_update_date, be_rewarded FROM user_login_event_data_other WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetLoginEventInfo_2016

CREATE OR REPLACE FUNCTION aion_getlogineventinfo_2016(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT event_id, stamp_count, recent_count_update_date, recent_anniversity_reward_time FROM user_login_event_data WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetLoginEventInfoRenewal

CREATE OR REPLACE FUNCTION aion_getlogineventinforenewal(
    p_accountId integer,
    p_specialsvrType integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT eventId, stampCount, recentCountUpdateDate FROM user_login_event_data_renewal WHERE accountId = p_accountId AND specialsvrType = p_specialsvrType;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetLunaReward

CREATE OR REPLACE FUNCTION aion_getlunareward(
    p_accountId integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_curdate timestamp;
    v_currentReward integer;
    v_remainReward integer;
    v_keycount integer;
    v_updateTime timestamp;
BEGIN
    v_currentReward := 0;
    v_remainReward := 0;
    v_keycount := 0;
    v_curdate := (CAST(TO_CHAR(CAST(CURRENT_TIMESTAMP + INTERVAL '9 hours' AS date), 'YYYYMMDD') AS integer));
    -- Transaction managed by PG function context
    SELECT today_reward, remain_reward, key_count, updatedate INTO v_currentReward, v_remainReward, v_keycount, v_updateTime FROM account_luna_reward where accountId = p_accountId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_currentReward := 0;
    v_remainReward := 0;
    v_keycount := 0;
    insert into account_luna_reward (accountId, today_reward, remain_reward, key_count) values (p_accountId, v_currentReward, v_remainReward, v_keycount);
    ELSE
    IF CURRENT_TIMESTAMP > v_curdate and v_updateTime <= v_curdate THEN
    v_currentReward := 0;
    v_remainReward := 0;
    update account_luna_reward set today_reward = v_currentReward, remain_reward = v_remainReward, updatedate = CURRENT_TIMESTAMP where accountId = p_accountId;
    END IF;
    END IF;
    -- COMMIT (implicit in PG function)
    PERFORM COALESCE(v_currentReward, 0), COALESCE(v_remainReward, 0), COALESCE(v_keycount,0);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetMonsterCoreInfo

CREATE OR REPLACE FUNCTION aion_getmonstercoreinfo(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	core_id, core_grade, core_count FROM	user_monster_core WHERE	account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetOldestCreateDate

CREATE OR REPLACE FUNCTION aion_getoldestcreatedate(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT COALESCE(min(create_date), 0) FROM global_user_data WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetPlayTimeForPoll

CREATE OR REPLACE FUNCTION aion_getplaytimeforpoll(
    p_poll_id integer,
    p_account_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_playTime bigint;
BEGIN
    v_playTime := 0;
    SELECT previous_playtime INTO v_playTime FROM account_playtime_polls  WHERE poll_id = p_poll_id AND account_id = p_account_id::integer;
    PERFORM COALESCE(v_playTime, 0) as previous_playtime;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetPlayTimesForPolls
--   Warning: Table variable converted to temp table
--   Warning: Table variable converted to temp table

CREATE OR REPLACE FUNCTION aion_getplaytimesforpolls(
    p_pollIds text,
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
DECLARE
    v_S_VAL text;
    v_S_SPLIT_CHAR varchar(1);
    v_oPos integer;
    v_nPos integer;
    v_i integer;
    v_tempVar varchar(4000);
    -- TODO: MANUAL REVIEW NEEDED - Table variable: DECLARE @T_SPLIT TABLE( NUM INT, VAL NVARCHAR(4000) )
    -- TODO: MANUAL REVIEW NEEDED - Table variable: DECLARE @PollIDList TABLE(poll_id INT)
BEGIN
    v_S_VAL := p_pollIds;
    v_S_SPLIT_CHAR := ',';
    v_oPos := 1;
    v_nPos := 1;
    v_i := 0;
    WHILE v_nPos > 0 LOOP
    v_nPos := POSITION(v_S_SPLIT_CHAR IN v_S_VAL);
    IF v_nPos = 0 THEN
    v_tempVar := RIGHT(v_S_VAL, LENGTH(v_S_VAL) - v_oPos + 1);
    ELSE
    v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos FOR v_nPos - v_oPos);
    END IF;
    IF LENGTH(v_tempVar) > 0 THEN
    INSERT INTO v_T_SPLIT VALUES (v_i, v_tempVar);
    END IF;
    v_oPos := v_nPos + 1;
    v_i := v_i + 1;
    END IF;
    INSERT INTO v_PollIDList SELECT CAST(VAL AS integer) FROM v_T_SPLIT;
    -- END (no matching block);
    RETURN QUERY SELECT templete.poll_id, COALESCE(app.previous_playtime, 0) as previous_playtime FROM v_PollIDList AS templete LEFT JOIN account_playtime_polls AS app ON app.poll_id = templete.poll_id AND app.account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetPromotionCoolTimeListForAC

CREATE OR REPLACE FUNCTION aion_getpromotioncooltimelistforac(
    p_nAccountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT promotion_id, last_promotion_time, received_item_count, cycle_received_item_count, cycle_next_reset_time FROM user_promotion_cooltime WHERE account_id = p_nAccountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetServerReplaceList

CREATE OR REPLACE FUNCTION aion_getserverreplacelist(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT orgServerId, newServerId from server_operation where operation = 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetTransformList

CREATE OR REPLACE FUNCTION aion_gettransformlist(
    p_account_id integer,
    p_server_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT name_id, count FROM user_transform WHERE (account_id = p_account_id::integer) AND (count > 0 and server_id = p_server_id::integer);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetTrialAccountData

CREATE OR REPLACE FUNCTION aion_gettrialaccountdata(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum from trial_account_data  WHERE account_id = p_accountId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_GetUnmatchLoginTimeUser

CREATE OR REPLACE FUNCTION aion_getunmatchlogintimeuser(
    p_serverId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT char_id from global_user_data where last_login_time >= last_logout_time and (EXTRACT(EPOCH FROM ('2000-01-01')::timestamp - (last_logout_time)::timestamp) / 86400)::integer < 0 and server_id = p_serverId::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_insert_test

CREATE OR REPLACE FUNCTION aion_insert_test(
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO test_data(int_value, nchar10_value, date_value) values(0, 'test', CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_loadLuna

CREATE OR REPLACE FUNCTION aion_loadluna(
    p_accid integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT luna from account_luna where accountId = p_accid;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_LoadLunaPrice

CREATE OR REPLACE FUNCTION aion_loadlunaprice(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time from user_luna_price where char_id = p_char_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_MonsterCoreAddCount

CREATE OR REPLACE FUNCTION aion_monstercoreaddcount(
    p_accountId integer,
    p_coreId integer,
    p_addCount integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    UPDATE	user_monster_core SET		core_count = core_count + p_addCount, total_added = total_added + p_addCount WHERE	account_id = p_accountId::integer AND core_id = p_coreId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF (v_rowcount = 0) THEN
    INSERT INTO user_monster_core (account_id, core_id, core_grade, core_count, total_added, total_used) VALUES (p_accountId, p_coreId, 0, p_addCount, p_addCount, 0);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_MonsterCoreUpdate

CREATE OR REPLACE FUNCTION aion_monstercoreupdate(
    p_accountId integer,
    p_coreId integer,
    p_coreGrade integer,
    p_coreCount integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    UPDATE	user_monster_core SET		core_count = p_coreCount, core_grade = p_coreGrade WHERE	account_id = p_accountId::integer AND core_id = p_coreId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF (v_rowcount = 0) THEN
    INSERT INTO user_monster_core (account_id, core_id, core_grade, core_count, total_added, total_used) VALUES (p_accountId, p_coreId, p_coreGrade, p_coreCount, p_coreCount, 0);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_MonsterCoreUpgradeAndDecreaseCount

CREATE OR REPLACE FUNCTION aion_monstercoreupgradeanddecreasecount(
    p_accountId integer,
    p_coreId integer,
    p_countForUpgrade integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	user_monster_core SET		core_grade = core_grade + 1, core_count = core_count - p_countForUpgrade, total_used = total_used + p_countForUpgrade WHERE	account_id = p_accountId::integer AND core_id = p_coreId;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_PutCosmetic

CREATE OR REPLACE FUNCTION aion_putcosmetic(
    p_nAccountID integer,
    p_nServerId smallint,
    p_nCharId integer,
    p_nRace smallint,
    p_nGender smallint,
    p_feat_version smallint,
    p_nHeadFaceColor integer,
    p_nHeadHairColor integer,
    p_nEyeColor integer,
    p_nLipColor integer,
    p_nHeadFaceType smallint,
    p_nHeadHairType smallint,
    p_fScale double precision,
    p_nVoiceType smallint,
    p_nFeatType1 smallint,
    p_nFeatType2 smallint,
    p_nHeadBumpType smallint,
    p_nHeadExpressionType smallint,
    p_feat_face_shape smallint,
    p_feat_forehead_shape smallint,
    p_feat_eye_position smallint,
    p_feat_eye_glabella smallint,
    p_feat_eye_length smallint,
    p_feat_eye_height smallint,
    p_feat_eye_shape smallint,
    p_feat_eye_tail smallint,
    p_feat_eyeblow_pos smallint,
    p_feat_eyeblow_angle smallint,
    p_feat_eyeblow_shape smallint,
    p_feat_nose_pos smallint,
    p_feat_nose_bridge smallint,
    p_feat_nose_side smallint,
    p_feat_nose_tip smallint,
    p_feat_cheek_shape smallint,
    p_feat_mouth_pos smallint,
    p_feat_mouth_size smallint,
    p_feat_lip_thickness smallint,
    p_feat_lip_tail smallint,
    p_feat_lip_shape smallint,
    p_feat_jaw_pos smallint,
    p_feat_jaw_shape smallint,
    p_feat_ear_shape smallint,
    p_feat_head_size smallint,
    p_feat_neck_thickness smallint,
    p_feat_neck_length smallint,
    p_feat_shoulder_size smallint,
    p_feat_upper_size smallint,
    p_feat_bust_size smallint,
    p_feat_waist_size smallint,
    p_feat_hip_size smallint,
    p_feat_arm_thickness smallint,
    p_feat_hand_size smallint,
    p_feat_leg_thickness smallint,
    p_feat_foot_size smallint,
    p_feat_face_ratio smallint,
    p_feat_wing_size smallint,
    p_feat_arm_length smallint,
    p_feat_leg_length smallint,
    p_feat_shoulder_width smallint,
    p_feat_head_figure smallint
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO cosmetic_data (account_id, server_id, char_id, race, gender, feat_version, head_face_color, head_hair_color, head_eye_color, head_lip_color, head_face_type, head_hair_type, height_scale, head_voice_type, head_feat_type1, head_feat_type2, head_bump_type, head_expression_type, feat_face_shape, feat_forehead_shape, feat_eye_position, feat_eye_glabella, feat_eye_length, feat_eye_height, feat_eye_shape, feat_eye_tail, feat_eyeblow_pos, feat_eyeblow_angle, feat_eyeblow_shape, feat_nose_pos, feat_nose_bridge, feat_nose_side, feat_nose_tip, feat_cheek_shape, feat_mouth_pos, feat_mouth_size, feat_lip_thickness, feat_lip_tail, feat_lip_shape, feat_jaw_pos, feat_jaw_shape, feat_ear_shape, feat_head_size, feat_neck_thickness, feat_neck_length, feat_shoulder_size, feat_upper_size, feat_bust_size, feat_waist_size, feat_hip_size, feat_arm_thickness, feat_hand_size, feat_leg_thickness, feat_foot_size, feat_face_ratio, feat_wing_size, feat_arm_length, feat_leg_length, feat_shoulder_width, feat_head_figure, create_date ) VALUES ( p_nAccountID, p_nServerId, p_nCharId, p_nRace, p_nGender, p_feat_version, p_nHeadFaceColor, p_nHeadHairColor, p_nEyeColor, p_nLipColor, p_nHeadFaceType, p_nHeadHairType, p_fScale, p_nVoiceType, p_nFeatType1, p_nFeatType2, p_nHeadBumpType, p_nHeadExpressionType, p_feat_face_shape, p_feat_forehead_shape, p_feat_eye_position, p_feat_eye_glabella, p_feat_eye_length, p_feat_eye_height, p_feat_eye_shape, p_feat_eye_tail, p_feat_eyeblow_pos, p_feat_eyeblow_angle, p_feat_eyeblow_shape, p_feat_nose_pos, p_feat_nose_bridge, p_feat_nose_side, p_feat_nose_tip, p_feat_cheek_shape, p_feat_mouth_pos, p_feat_mouth_size, p_feat_lip_thickness, p_feat_lip_tail, p_feat_lip_shape, p_feat_jaw_pos, p_feat_jaw_shape, p_feat_ear_shape, p_feat_head_size, p_feat_neck_thickness, p_feat_neck_length, p_feat_shoulder_size, p_feat_upper_size, p_feat_bust_size, p_feat_waist_size, p_feat_hip_size, p_feat_arm_thickness, p_feat_hand_size, p_feat_leg_thickness, p_feat_foot_size, p_feat_face_ratio, p_feat_wing_size, p_feat_arm_length, p_feat_leg_length, p_feat_shoulder_width, p_feat_head_figure, CURRENT_TIMESTAMP );
    IF 0 /* @v_ERROR */ <> 0 THEN
    RETURN 0;
    END IF;
    RETURN LASTVAL();
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_PutTransform

CREATE OR REPLACE FUNCTION aion_puttransform(
    p_account_id integer,
    p_name_id integer,
    p_count integer,
    p_server_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM user_transform  WHERE account_id = p_account_id::integer AND name_id = p_name_id and server_id = p_server_id::integer) THEN
    UPDATE user_transform SET count = p_count::integer, update_time = CURRENT_TIMESTAMP WHERE account_id = p_account_id::integer AND name_id = p_name_id and server_id = p_server_id::integer;
    ELSE
    INSERT INTO user_transform(account_id, name_id, count,server_id) VALUES (p_account_id, p_name_id, p_count,p_server_id);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aion_PutUserDataFromAllServer
--   Warning: CURSOR logic detected - converted to PG cursor syntax

CREATE OR REPLACE FUNCTION aion_putuserdatafromallserver(
    p_db_userId varchar(64),
    p_db_passwd varchar(64)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_fetch_found boolean := true;
    v_server_id integer;
    v_sync_server_id integer;
    v_ret integer;
    syncChar_cursor CURSOR FOR select server_id from aion_serverlist;
BEGIN
    OPEN syncChar_cursor;
    FETCH syncChar_cursor INTO v_sync_server_id;
    v_fetch_found := FOUND;
    WHILE v_fetch_found LOOP
    v_ret := -10000;
    PERFORM aion_PutUserDataFromServer(p_db_userId, p_db_passwd, v_sync_server_id, v_ret);
    update aion_serverlist set update_result = v_ret where server_id = v_sync_server_id;
    FETCH syncChar_cursor INTO v_sync_server_id;
    v_fetch_found := FOUND;
    END LOOP;
    CLOSE syncChar_cursor;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_PutUserDataFromServer

CREATE OR REPLACE FUNCTION aion_putuserdatafromserver(
    p_db_userId varchar(64),
    p_db_passwd varchar(64),
    p_serverId integer,
    OUT p_ret integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_serverName varchar(128);
    v_databaseName varchar(64);
    v_db_info varchar(256);
    v_sql varchar(4000);
BEGIN
    v_serverName := '';
    v_databaseName := '';
    SELECT datasource, database_name INTO v_serverName, v_databaseName FROM aion_serverlist where server_id = p_serverId::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ret := -1;
    RETURN;
    END IF;
    v_db_info := '''' || v_serverName || ''';''' || p_db_userId || ''';''' || p_db_passwd || '''';
    v_sql := 'insert into global_user_data(' || ' char_id, account_id, create_date, last_login_time, last_logout_time, delete_date, delete_completed_date, user_level, server_id' || ') ' || ' select ' || ' o.char_id, o.account_id, o.create_date, o.last_login_time, o.last_logout_time, o.delete_date, o.delete_complete_date, o.lev, ' || ' ' || CAST(p_serverId AS varchar) || ' from openrowset (''SQLOLEDB'', ' || v_db_info || ',' || ' ''select char_id, account_id, lev, create_date, last_login_time, last_logout_time, delete_date, delete_complete_date from ' || v_databaseName || '.user_data '' ) as o' || ' left join global_user_data on global_user_data.char_id = o.char_id and global_user_data.server_id = ' || CAST(p_serverId AS varchar) || ' where global_user_data.char_id is null';
    EXECUTE v_sql;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    p_ret := v_rowcount;
    IF 0 /* @v_ERROR */ <> 0 THEN
    p_ret := -2;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_QueryCanCreateJumpingCharacter

CREATE OR REPLACE FUNCTION aion_querycancreatejumpingcharacter(
    p_account_id integer,
    p_server_id integer,
    p_from_special smallint,
    OUT p_can_create_num integer,
    OUT p_satisfy_date smallint,
    OUT p_satisfy_char_lev smallint
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur_date timestamp;
    v_max_creation_count integer;
    v_required_char_level integer;
    v_start_date timestamp;
    v_end_date timestamp;
    v_cur_creation_num integer;
BEGIN
    v_cur_date := CURRENT_TIMESTAMP;
    SELECT max_creation_count, required_char_level, start_date, end_date INTO v_max_creation_count, v_required_char_level, v_start_date, v_end_date FROM jumping_character_config WHERE server_id = p_server_id::integer and start_date < v_cur_date and v_cur_date < end_date and is_deleted = 0;
    IF (COALESCE(v_max_creation_count, 0) > 0) THEN
    p_satisfy_date := 1;
    IF (EXISTS(SELECT char_id FROM global_user_data WHERE account_id = p_account_id::integer and is_special_server = p_from_special and user_level >= v_required_char_level and delete_completed_date = 0) OR v_required_char_level = 0) THEN
    p_satisfy_char_lev := 1;
    SELECT COUNT(*) INTO v_cur_creation_num FROM global_user_data WHERE account_id = p_account_id::integer and is_special_server = p_from_special and create_date > v_start_date and create_date < v_end_date and is_jumping_character != 0;
    v_cur_creation_num := COALESCE(v_cur_creation_num, 0);
    p_can_create_num := v_max_creation_count - v_cur_creation_num;
    ELSE
    p_satisfy_char_lev := 0;
    p_can_create_num := 0;
    ELSE
    p_satisfy_date := 0;
    p_satisfy_char_lev := 0;
    p_can_create_num := 0;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_QueryCanCreateJumpingCharacter_20170428

CREATE OR REPLACE FUNCTION aion_querycancreatejumpingcharacter_20170428(
    p_account_id integer,
    p_server_id integer,
    p_from_special smallint,
    OUT p_can_create_num integer,
    OUT p_satisfy_date smallint,
    OUT p_satisfy_char_lev smallint,
    OUT p_limit_reset_time integer,
    OUT p_limit_play_time integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur_date timestamp;
    v_max_creation_count integer;
    v_required_char_level integer;
    v_start_date timestamp;
    v_end_date timestamp;
    v_cur_creation_num integer;
BEGIN
    v_cur_date := CURRENT_TIMESTAMP;
    SELECT max_creation_count, required_char_level, start_date, end_date INTO v_max_creation_count, v_required_char_level, v_start_date, v_end_date FROM jumping_character_config WHERE server_id = p_server_id::integer and start_date < v_cur_date and v_cur_date < end_date and is_deleted = 0;
    IF (COALESCE(v_max_creation_count, 0) > 0) THEN
    p_satisfy_date := 1;
    IF (EXISTS(SELECT char_id FROM global_user_data WHERE account_id = p_account_id::integer and is_special_server = p_from_special and user_level >= v_required_char_level and delete_completed_date = 0) OR v_required_char_level = 0) THEN
    p_satisfy_char_lev := 1;
    SELECT COUNT(*) INTO v_cur_creation_num FROM global_user_data WHERE account_id = p_account_id::integer and is_special_server = p_from_special and create_date > v_start_date and create_date < v_end_date and is_jumping_character != 0;
    v_cur_creation_num := COALESCE(v_cur_creation_num, 0);
    p_can_create_num := v_max_creation_count - v_cur_creation_num;
    SELECT limit_play_reset_time, limit_play_accum_time INTO p_limit_reset_time, p_limit_play_time FROM account_data WHERE account_id = p_account_id::integer;
    p_limit_reset_time := COALESCE(p_limit_reset_time, 0);
    p_limit_play_time := COALESCE(p_limit_play_time, 0);
    ELSE
    p_satisfy_char_lev := 0;
    p_can_create_num := 0;
    p_limit_reset_time := 0;
    p_limit_play_time := 0;
    ELSE
    p_satisfy_date := 0;
    p_satisfy_char_lev := 0;
    p_can_create_num := 0;
    p_limit_reset_time := 0;
    p_limit_play_time := 0;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_ResetLunaReward

CREATE OR REPLACE FUNCTION aion_resetlunareward(
    p_accountId integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentReward integer;
    v_remainReward integer;
    v_updateTime timestamp;
    v_curdate timestamp;
BEGIN
    v_currentReward := 0;
    v_remainReward := 0;
    v_curdate := (CAST(TO_CHAR(CAST(CURRENT_TIMESTAMP + INTERVAL '9 hours' AS date), 'YYYYMMDD') AS integer));
    -- Transaction managed by PG function context
    SELECT today_reward, remain_reward, updatedate INTO v_currentReward, v_remainReward, v_updateTime FROM account_luna_reward where accountId = p_accountId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount <> 0 THEN
    IF CURRENT_TIMESTAMP > v_curdate and  v_updateTime <= v_curdate THEN
    v_currentReward := 0;
    v_remainReward := 0;
    update account_luna_reward set today_reward = v_currentReward, remain_reward = v_remainReward, updatedate = CURRENT_TIMESTAMP where accountId = p_accountId;
    END IF;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_select_test

CREATE OR REPLACE FUNCTION aion_select_test(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from test_data;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetAccountData

CREATE OR REPLACE FUNCTION aion_setaccountdata(
    p_accountId integer,
    p_hidden_fatigue_point integer,
    p_hidden_fatigue_updatetime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM account_data WHERE account_id = p_accountId::integer) THEN
    UPDATE account_data SET hidden_fatigue_point = hidden_fatigue_point;
    ELSE
    INSERT INTO account_data(account_id, hidden_fatigue_point, hidden_fatigue_updatetime) VALUES (p_accountId, p_hidden_fatigue_point, p_hidden_fatigue_updatetime);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetAccountPack

CREATE OR REPLACE FUNCTION aion_setaccountpack(
    p_accountId integer,
    p_packType smallint,
    p_expireDate integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM account_pack WHERE account_id = p_accountId::integer and pack_type=p_packType) THEN
    UPDATE account_pack SET expire_date = p_expireDate WHERE account_id = p_accountId::integer and pack_type=p_packType;
    ELSE
    INSERT INTO account_pack(account_id, pack_type, expire_date) VALUES (p_accountId, p_packType, p_expireDate);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetCreateUser_20120703

CREATE OR REPLACE FUNCTION aion_setcreateuser_20120703(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_account_id integer,
    p_create_date timestamp
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, cur_server_id = p_cur_server_id WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, server_id, cur_server_id, user_level) VALUES (p_char_id, p_account_id, p_create_date, p_server_id, p_cur_server_id, 1);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetCreateUser_20121206

CREATE OR REPLACE FUNCTION aion_setcreateuser_20121206(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_account_id integer,
    p_create_date timestamp,
    p_class_type integer,
    p_race_type integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, cur_server_id = p_cur_server_id, class_type = p_class_type, race_type = p_race_type WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, server_id, cur_server_id, user_level, class_type, race_type) VALUES (p_char_id, p_account_id, p_create_date, p_server_id, p_cur_server_id, 1, p_class_type, p_race_type);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetCreateUser_20160303

CREATE OR REPLACE FUNCTION aion_setcreateuser_20160303(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_account_id integer,
    p_create_date timestamp,
    p_class_type integer,
    p_race_type integer,
    p_level integer,
    p_is_special_server smallint,
    p_is_jumping_character smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, cur_server_id = p_cur_server_id, class_type = p_class_type, race_type = p_race_type WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, server_id, cur_server_id, user_level, class_type, race_type, is_special_server, is_jumping_character) VALUES (p_char_id, p_account_id, p_create_date, p_server_id, p_cur_server_id, p_level, p_class_type, p_race_type, p_is_special_server, p_is_jumping_character);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetDeleteCompletedUser_20120703

CREATE OR REPLACE FUNCTION aion_setdeletecompleteduser_20120703(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_delete_completed_time integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set delete_completed_date = p_delete_completed_time, cur_server_id = p_cur_server_id where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetDeleteUser_20120703

CREATE OR REPLACE FUNCTION aion_setdeleteuser_20120703(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_delete_time integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set delete_date = p_delete_time, cur_server_id = p_cur_server_id where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetLoginUser_20120703

CREATE OR REPLACE FUNCTION aion_setloginuser_20120703(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_login_time timestamp
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set last_login_time = p_login_time,cur_server_id = p_cur_server_id , last_logout_time = p_login_time where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetLoginUser_20121120

CREATE OR REPLACE FUNCTION aion_setloginuser_20121120(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_login_time timestamp,
    p_global_char_id bigint
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set last_login_time = p_login_time,cur_server_id = p_cur_server_id , last_logout_time = p_login_time, global_char_id = p_global_char_id where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetLoginUser_20121206

CREATE OR REPLACE FUNCTION aion_setloginuser_20121206(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_login_time timestamp,
    p_global_char_id bigint,
    p_class_type integer,
    p_race_type integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set last_login_time = p_login_time,cur_server_id = p_cur_server_id , last_logout_time = p_login_time, global_char_id = p_global_char_id, class_type = p_class_type, race_type = p_race_type , delete_date = 0, delete_completed_date = 0 where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetLogoutUser_20120703

CREATE OR REPLACE FUNCTION aion_setlogoutuser_20120703(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_logout_time timestamp
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set last_logout_time = p_logout_time, cur_server_id = p_cur_server_id where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetLogoutUser_20121206

CREATE OR REPLACE FUNCTION aion_setlogoutuser_20121206(
    p_char_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_logout_time timestamp,
    p_class_type integer,
    p_race_type integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set last_logout_time = p_logout_time, cur_server_id = p_cur_server_id, class_type = p_class_type, race_type = p_race_type where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetPromotionCooltimeForAC

CREATE OR REPLACE FUNCTION aion_setpromotioncooltimeforac(
    p_nCharId integer,
    p_nPromotionId smallint,
    p_nLastPromotionTime integer,
    p_nReceivedItemCount integer,
    p_nCycleReceivedItemCount integer,
    p_nCycleNextResetTime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT promotion_id FROM user_promotion_cooltime WHERE account_id = p_nCharId::integer and promotion_id=p_nPromotionId) THEN
    UPDATE user_promotion_cooltime SET last_promotion_time = p_nLastPromotionTime, received_item_count = p_nReceivedItemCount, cycle_received_item_count = p_nCycleReceivedItemCount, cycle_next_reset_time = p_nCycleNextResetTime WHERE account_id = p_nCharId::integer and promotion_id=p_nPromotionId;
    ELSE
    INSERT INTO user_promotion_cooltime(account_id, promotion_id, last_promotion_time, received_item_count, cycle_received_item_count, cycle_next_reset_time) VALUES (p_nCharId, p_nPromotionId, p_nLastPromotionTime, p_nReceivedItemCount, p_nCycleReceivedItemCount, p_nCycleNextResetTime);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetTrialAccountData

CREATE OR REPLACE FUNCTION aion_settrialaccountdata(
    p_accountId integer,
    p_updateTime integer,
    p_resetTime integer,
    p_sellGold bigint,
    p_tradeGold bigint,
    p_decomposeSum integer,
    p_gatherSum integer,
    p_extractGatherSum integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM trial_account_data WHERE account_id = p_accountId::integer) THEN
    UPDATE trial_account_data SET update_time=p_updateTime, reset_time=p_resetTime, sell_gold_sum=p_sellGold, trade_gold_sum=p_tradeGold, decompose_sum=p_decomposeSum, gather_sum=p_gatherSum, extract_gather_sum=p_extractGatherSum WHERE account_id = p_accountId::integer AND p_updateTime > update_time;
    ELSE
    INSERT INTO trial_account_data(account_id, update_time, reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum) VALUES (p_accountId, p_updateTime, p_resetTime, p_sellGold, p_tradeGold, p_decomposeSum, p_gatherSum, p_extractGatherSum);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetUserInfo_20120703

CREATE OR REPLACE FUNCTION aion_setuserinfo_20120703(
    p_char_id integer,
    p_account_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_char_lev integer,
    p_create_date timestamp,
    p_login_time timestamp,
    p_logout_time timestamp,
    p_delete_date integer,
    p_delete_complete_date integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_utc_adjust bigint;
BEGIN
    v_utc_adjust := GetUtcAdjustSecWithUTC_Local((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'), CURRENT_TIMESTAMP);
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, last_login_time = p_login_time, last_logout_time = p_logout_time, delete_date = p_delete_date, delete_completed_date = p_delete_complete_date, user_level = p_char_lev, cur_server_id = p_cur_server_id WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, last_login_time, last_logout_time, delete_date, delete_completed_date, server_id, cur_server_id, user_level) VALUES (p_char_id, p_account_id , p_create_date , p_login_time , p_logout_time , p_delete_date , p_delete_complete_date , p_server_id, p_cur_server_id, p_char_lev);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetUserInfo_20121210

CREATE OR REPLACE FUNCTION aion_setuserinfo_20121210(
    p_char_id integer,
    p_account_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_char_lev integer,
    p_create_date timestamp,
    p_login_time timestamp,
    p_logout_time timestamp,
    p_delete_date integer,
    p_delete_complete_date integer,
    p_class_type integer,
    p_race_type integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_utc_adjust bigint;
BEGIN
    v_utc_adjust := GetUtcAdjustSecWithUTC_Local((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'), CURRENT_TIMESTAMP);
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, last_login_time = p_login_time, last_logout_time = p_logout_time, delete_date = p_delete_date, delete_completed_date = p_delete_complete_date, user_level = p_char_lev, cur_server_id = p_cur_server_id, class_type = p_class_type, race_type = p_race_type WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, last_login_time, last_logout_time, delete_date, delete_completed_date, server_id, cur_server_id, user_level, class_type, race_type) VALUES (p_char_id, p_account_id , p_create_date , p_login_time , p_logout_time , p_delete_date , p_delete_complete_date , p_server_id , p_cur_server_id , p_char_lev , p_class_type , p_race_type);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetUserInfo_20160303

CREATE OR REPLACE FUNCTION aion_setuserinfo_20160303(
    p_char_id integer,
    p_account_id integer,
    p_server_id integer,
    p_cur_server_id integer,
    p_char_lev integer,
    p_create_date timestamp,
    p_login_time timestamp,
    p_logout_time timestamp,
    p_delete_date integer,
    p_delete_complete_date integer,
    p_class_type integer,
    p_race_type integer,
    p_is_special_server smallint,
    p_is_jumping_character smallint
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_utc_adjust bigint;
BEGIN
    v_utc_adjust := GetUtcAdjustSecWithUTC_Local((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'), CURRENT_TIMESTAMP);
    IF EXISTS (select char_id from global_user_data where char_id = p_char_id::integer and server_id = p_server_id::integer) THEN
    UPDATE global_user_data SET create_date = p_create_date, last_login_time = p_login_time, last_logout_time = p_logout_time, delete_date = p_delete_date, delete_completed_date = p_delete_complete_date, user_level = p_char_lev, cur_server_id = p_cur_server_id, class_type = p_class_type, race_type = p_race_type, is_special_server = p_is_special_server, is_jumping_character = p_is_jumping_character WHERE char_id = p_char_id::integer and server_id = p_server_id::integer;
    ELSE
    INSERT INTO global_user_data(char_id, account_id, create_date, last_login_time, last_logout_time, delete_date, delete_completed_date, server_id, cur_server_id, user_level, class_type, race_type, is_special_server, is_jumping_character) VALUES (p_char_id, p_account_id , p_create_date , p_login_time , p_logout_time , p_delete_date , p_delete_complete_date , p_server_id , p_cur_server_id , p_char_lev , p_class_type , p_race_type , p_is_special_server, p_is_jumping_character);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SetUserLevelChanged

CREATE OR REPLACE FUNCTION aion_setuserlevelchanged(
    p_char_id integer,
    p_server_id integer,
    p_char_level bigint
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    update global_user_data set user_level = p_char_level where char_id = p_char_id::integer and server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_SyncUserDataFromServer

CREATE OR REPLACE FUNCTION aion_syncuserdatafromserver(
    p_db_userId varchar(64),
    p_db_passwd varchar(64),
    p_serverId integer,
    OUT p_ret integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_serverName varchar(128);
    v_databaseName varchar(64);
    v_db_info varchar(256);
    v_sql varchar(4000);
BEGIN
    v_serverName := '';
    v_databaseName := '';
    SELECT datasource, database_name INTO v_serverName, v_databaseName FROM aion_serverlist where server_id = p_serverId::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ret := -1;
    RETURN;
    END IF;
    v_db_info := '''' || v_serverName || ''';''' || p_db_userId || ''';''' || p_db_passwd || '''';
    v_sql := 'update global_user_data' || ' set create_date = o.create_date, last_login_time = o.last_login_time, last_logout_time = o.last_logout_time, delete_date = o.delete_date, delete_completed_date = o.delete_complete_date, user_level = o.lev' || ' from global_user_data' || ' join openrowset (''SQLOLEDB'', ' || v_db_info || ',' || ' ''select char_id, account_id, lev, create_date, last_login_time, last_logout_time, delete_date, delete_complete_date from ' || v_databaseName || '.user_data '' ) as o' || '   on global_user_data.char_id = o.char_id ' || ' 	and ( global_user_data.create_date != o.create_date ' || ' 			or global_user_data.last_login_time != o.last_login_time ' || ' 			or global_user_data.last_logout_time != o.last_logout_time ' || ' 			or global_user_data.delete_date != o.delete_date ' || ' 			or global_user_data.delete_completed_date != o.delete_complete_date ' || ' 			or global_user_data.user_level != o.lev )	' || '	where global_user_data.server_id = ' || CAST(p_serverId AS varchar);
    EXECUTE v_sql;
    IF 0 /* @v_ERROR */ <> 0 THEN
    p_ret := -2;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateBoardBMState

CREATE OR REPLACE FUNCTION aion_updateboardbmstate(
    p_account_id integer,
    p_game_id integer,
    p_current_pos integer,
    p_visited_pos bigint,
    p_last_freecharge_time bigint,
    p_last_reset_teim bigint,
    p_free_dice_remain integer,
    p_paid_dice_remain integer,
    p_paid_reset_remain integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT account_id FROM user_board_bm WHERE account_id = p_account_id::integer) THEN
    UPDATE user_board_bm SET game_id = p_game_id, current_pos = p_current_pos, visited_pos = p_visited_pos, last_freecharge_time = p_last_freecharge_time, last_reset_time = p_last_reset_teim, free_dice_remain = p_free_dice_remain, paid_dice_remain = p_paid_dice_remain, paid_reset_remain = p_paid_reset_remain WHERE account_id = p_account_id::integer;
    ELSE
    INSERT INTO user_board_bm(account_id, game_id, current_pos, visited_pos, last_freecharge_time, last_reset_time, free_dice_remain, paid_dice_remain, paid_reset_remain) VALUES (p_account_id, p_game_id, p_current_pos, p_visited_pos, p_last_freecharge_time, p_last_reset_teim, p_free_dice_remain, p_paid_dice_remain, p_paid_reset_remain);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateBoardBMState_2017

CREATE OR REPLACE FUNCTION aion_updateboardbmstate_2017(
    p_account_id integer,
    p_isSpecial integer,
    p_game_id integer,
    p_current_pos integer,
    p_visited_pos bigint,
    p_last_freecharge_time bigint,
    p_last_reset_time bigint,
    p_free_dice_remain integer,
    p_paid_dice_remain integer,
    p_paid_reset_remain integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT account_id FROM user_board_bm_dice WHERE account_id = p_account_id::integer) THEN
    UPDATE user_board_bm_dice SET last_freecharge_time = p_last_freecharge_time, free_dice_remain = p_free_dice_remain, paid_dice_remain = p_paid_dice_remain, paid_reset_remain = p_paid_reset_remain WHERE account_id = p_account_id::integer;
    ELSE
    INSERT INTO user_board_bm_dice(account_id, last_freecharge_time, free_dice_remain, paid_dice_remain, paid_reset_remain) VALUES (p_account_id, p_last_freecharge_time, p_free_dice_remain, p_paid_dice_remain, p_paid_reset_remain);
    END IF;
    IF EXISTS (SELECT account_id FROM user_board_bm_game WHERE account_id = p_account_id::integer and is_special_server = p_isSpecial) THEN
    UPDATE user_board_bm_game SET game_id = p_game_id, current_pos = p_current_pos, visited_pos = p_visited_pos, last_reset_time = p_last_reset_time WHERE account_id = p_account_id::integer and is_special_server = p_isSpecial;
    ELSE
    INSERT INTO user_board_bm_game(account_id, is_special_server, game_id, current_pos, visited_pos, last_reset_time) VALUES (p_account_id, p_isSpecial, p_game_id, p_current_pos, p_visited_pos, p_last_reset_time);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateHiddenFatigueInfo

CREATE OR REPLACE FUNCTION aion_updatehiddenfatigueinfo(
    p_accountId integer,
    p_hidden_fatigue_point integer,
    p_hidden_fatigue_updatetime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM account_data WHERE account_id = p_accountId::integer) THEN
    UPDATE account_data SET hidden_fatigue_point = p_hidden_fatigue_point, hidden_fatigue_updatetime = p_hidden_fatigue_updatetime where account_id = p_accountId::integer;
    ELSE
    INSERT INTO account_data(account_id, hidden_fatigue_point, hidden_fatigue_updatetime) VALUES (p_accountId, p_hidden_fatigue_point, p_hidden_fatigue_updatetime);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateHiddenFatigueInfo_20151002

CREATE OR REPLACE FUNCTION aion_updatehiddenfatigueinfo_20151002(
    p_accountId integer,
    p_hidden_fatigue_point integer,
    p_hidden_fatigue_npcKill integer,
    p_hidden_fatigue_updatetime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM account_data WHERE account_id = p_accountId::integer) THEN
    UPDATE account_data SET hidden_fatigue_point = p_hidden_fatigue_point,hidden_fatigue_npckill = p_hidden_fatigue_npcKill,  hidden_fatigue_updatetime = p_hidden_fatigue_updatetime where account_id = p_accountId::integer;
    ELSE
    INSERT INTO account_data(account_id, hidden_fatigue_point, hidden_fatigue_npckill, hidden_fatigue_updatetime) VALUES (p_accountId, p_hidden_fatigue_point, p_hidden_fatigue_npcKill, p_hidden_fatigue_updatetime);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateHiddenFatigueInfo_20170428

CREATE OR REPLACE FUNCTION aion_updatehiddenfatigueinfo_20170428(
    p_accountId integer,
    p_hidden_fatigue_point integer,
    p_hidden_fatigue_npcKill integer,
    p_hidden_fatigue_updatetime integer,
    p_limit_reset_time integer,
    p_limit_play_time integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT account_id FROM account_data WHERE account_id = p_accountId::integer) THEN
    UPDATE account_data SET hidden_fatigue_point = p_hidden_fatigue_point,hidden_fatigue_npckill = p_hidden_fatigue_npcKill,  hidden_fatigue_updatetime = p_hidden_fatigue_updatetime,  limit_play_reset_time = p_limit_reset_time,  limit_play_accum_time = p_limit_play_time where account_id = p_accountId::integer;
    ELSE
    INSERT INTO account_data(account_id, hidden_fatigue_point, hidden_fatigue_npckill, hidden_fatigue_updatetime, limit_play_reset_time, limit_play_accum_time) VALUES (p_accountId, p_hidden_fatigue_point, p_hidden_fatigue_npcKill, p_hidden_fatigue_updatetime, p_limit_reset_time, p_limit_play_time);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLoginEventInfo

CREATE OR REPLACE FUNCTION aion_updatelogineventinfo(
    p_account_id integer,
    p_event_id integer,
    p_stamp_count integer,
    p_recent_count_update_date timestamp,
    p_recent_anniversity_reward_time bigint
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT account_id FROM user_login_event_data WHERE account_id = p_account_id::integer) THEN
    UPDATE user_login_event_data SET event_id = p_event_id, stamp_count = p_stamp_count, recent_count_update_date = p_recent_count_update_date, recent_anniversity_reward_time = p_recent_anniversity_reward_time WHERE account_id = p_account_id::integer;
    ELSE
    INSERT INTO user_login_event_data(account_id, event_id, stamp_count, recent_count_update_date, recent_anniversity_reward_time) VALUES (p_account_id, p_event_id, p_stamp_count, p_recent_count_update_date, p_recent_anniversity_reward_time);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLoginEventInfo_daily

CREATE OR REPLACE FUNCTION aion_updatelogineventinfo_daily(
    p_account_id integer,
    p_event_id integer,
    p_recent_count_update_date timestamp,
    p_be_rewarded integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT account_id FROM user_login_event_data_daily WHERE account_id = p_account_id::integer AND event_id=p_event_id AND recent_count_update_date = p_recent_count_update_date) THEN
    UPDATE user_login_event_data_daily SET be_rewarded = p_be_rewarded WHERE account_id = p_account_id::integer AND event_id = p_event_id AND recent_count_update_date = p_recent_count_update_date;
    ELSE
    INSERT INTO user_login_event_data_daily(account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded) VALUES (p_account_id, p_event_id, 0, p_recent_count_update_date, p_be_rewarded);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLoginEventInfo_other

CREATE OR REPLACE FUNCTION aion_updatelogineventinfo_other(
    p_account_id integer,
    p_event_id integer,
    p_valid_login_count integer,
    p_recent_count_update_date timestamp,
    p_be_rewarded integer
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT account_id FROM user_login_event_data_other WHERE account_id = p_account_id::integer AND event_id=p_event_id) THEN
    UPDATE user_login_event_data_other SET valid_login_count = p_valid_login_count, recent_count_update_date = p_recent_count_update_date, be_rewarded = p_be_rewarded WHERE account_id = p_account_id::integer AND event_id = p_event_id;
    ELSE
    INSERT INTO user_login_event_data_other(account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded) VALUES (p_account_id, p_event_id, p_valid_login_count, p_recent_count_update_date, p_be_rewarded);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLoginEventInfoRenewal

CREATE OR REPLACE FUNCTION aion_updatelogineventinforenewal(
    p_accountId integer,
    p_specialsvrType integer,
    p_eventId integer,
    p_stampCount integer,
    p_recentCountUpdateDate timestamp
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    IF EXISTS (SELECT accountId FROM user_login_event_data_renewal WHERE accountId = p_accountId AND specialsvrType = p_specialsvrType AND eventId = p_eventId) THEN
    UPDATE user_login_event_data_renewal SET accountId = p_accountId, specialsvrType = p_specialsvrType, eventId = p_eventId, stampCount = p_stampCount, recentCountUpdateDate = p_recentCountUpdateDate WHERE accountId = p_accountId AND specialsvrType = p_specialsvrType AND eventId = p_eventId;
    ELSE
    INSERT INTO user_login_event_data_renewal(accountId,	specialsvrType,	eventId, stampCount, recentCountUpdateDate) VALUES (p_accountId,	p_specialsvrType, p_eventId, p_stampCount, p_recentCountUpdateDate);
    END IF;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLuna

CREATE OR REPLACE FUNCTION aion_updateluna(
    p_accId integer,
    p_deltaLuna bigint
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentLuna bigint;
BEGIN
    -- Transaction managed by PG function context
    v_currentLuna := 0;
    SELECT COALESCE(luna,0) INTO v_currentLuna FROM account_luna where accountId = p_accId;
    IF (v_currentLuna + p_deltaLuna) < 0 THEN
    -- COMMIT (implicit in PG function)
    RETURN -2;
    ELSE
    update account_luna set luna = luna + p_deltaLuna, updatedate = CURRENT_TIMESTAMP where accountId = p_accId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    insert into account_luna (accountId, luna) values (p_accId, p_deltaLuna);
    END IF;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLunaPrice

CREATE OR REPLACE FUNCTION aion_updatelunaprice(
    p_char_id integer,
    p_luna_id integer,
    p_use_count integer,
    p_reset_type smallint,
    p_reset_week_value smallint,
    p_reset_time_value integer,
    p_create_time bigint
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    -- Transaction managed by PG function context
    IF p_use_count = 0 and p_create_time = 0 THEN
    update user_luna_price set use_count = p_use_count, create_time = p_create_time where char_id = p_char_id::integer and luna_id = p_luna_id;
    ELSE
    update user_luna_price set use_count = p_use_count, update_time = CURRENT_TIMESTAMP where char_id = p_char_id::integer and luna_id = p_luna_id and create_time != 0;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    update user_luna_price set use_count = p_use_count, update_time = CURRENT_TIMESTAMP, create_time = p_create_time where char_id = p_char_id::integer and luna_id = p_luna_id and create_time = 0;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    insert into user_luna_price (char_id, luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time) values (p_char_id, p_luna_id, p_use_count, p_reset_type, p_reset_week_value, p_reset_time_value, p_create_time);
    END IF;
    END IF;
    END IF;
    -- COMMIT (implicit in PG function)
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdateLunaReward

CREATE OR REPLACE FUNCTION aion_updatelunareward(
    p_accountId integer,
    p_reward_point integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentReward integer;
    v_remainReward integer;
    v_updateTime timestamp;
    v_curdate timestamp;
BEGIN
    v_currentReward := 0;
    v_remainReward := 0;
    v_curdate := (CAST(TO_CHAR(CAST(CURRENT_TIMESTAMP + INTERVAL '9 hours' AS date), 'YYYYMMDD') AS integer));
    IF p_reward_point < 0 THEN
    RETURN -1;
    END IF;
    -- Transaction managed by PG function context
    SELECT today_reward, remain_reward, updatedate INTO v_currentReward, v_remainReward, v_updateTime FROM account_luna_reward where accountId = p_accountId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_currentReward := p_reward_point;
    v_remainReward := p_reward_point;
    insert into account_luna_reward (accountId, today_reward, remain_reward) values (p_accountId, v_currentReward, v_remainReward);
    ELSE
    IF CURRENT_TIMESTAMP > v_curdate and  v_updateTime <= v_curdate THEN
    v_currentReward := p_reward_point;
    v_remainReward := p_reward_point;
    ELSE
    v_currentReward := v_currentReward + p_reward_point;
    v_remainReward := v_remainReward;
    END IF;
    update account_luna_reward set today_reward = v_currentReward, remain_reward = v_remainReward, updatedate = CURRENT_TIMESTAMP where accountId = p_accountId;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdatePlayTimeForPoll

CREATE OR REPLACE FUNCTION aion_updateplaytimeforpoll(
    p_poll_id integer,
    p_account_id integer,
    p_play_time bigint
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_current_playtime bigint;
BEGIN
    v_current_playtime := 0;
    -- Transaction managed by PG function context
    SELECT previous_playtime INTO v_current_playtime FROM account_playtime_polls  WHERE poll_id = p_poll_id AND account_id = p_account_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    INSERT INTO account_playtime_polls (account_id, poll_id, previous_playtime) VALUES (p_account_id, p_poll_id, p_play_time);
    ELSE
    UPDATE account_playtime_polls SET previous_playtime = previous_playtime + p_play_time WHERE poll_id = p_poll_id AND account_id = p_account_id::integer;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN QUERY SELECT COALESCE(previous_playtime, 0) as previous_playtime WHERE poll_id = p_poll_id AND account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aion_UpdatePlayTimesForPolls
--   Warning: Table variable converted to temp table

CREATE OR REPLACE FUNCTION aion_updateplaytimesforpolls(
    p_pollIds text,
    p_playTimes text,
    p_account_id integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_S_VAL text;
    v_S_VAL_TIME text;
    v_S_SPLIT_CHAR varchar(1);
    v_oPos integer;
    v_nPos integer;
    v_oPos_t integer;
    v_nPos_t integer;
    v_i integer;
    v_tempVar varchar(4000);
    v_tempVar_t varchar(4000);
    v_tempPollId integer;
    v_tempPlayTime bigint;
    -- TODO: MANUAL REVIEW NEEDED - Table variable: DECLARE @PollIDTimeList TABLE ( poll_id INT, PlayTime BIGINT )
BEGIN
    v_S_VAL := p_pollIds;
    v_S_VAL_TIME := p_playTimes;
    v_S_SPLIT_CHAR := ',';
    v_oPos := 1;
    v_oPos_t := 1;
    v_nPos := 1;
    v_nPos_t := 1;
    WHILE v_nPos > 0 AND v_nPos_t > 0 LOOP
    v_nPos := POSITION(v_S_SPLIT_CHAR IN v_S_VAL);
    v_nPos_t := POSITION(v_S_SPLIT_CHAR IN v_S_VAL_TIME);
    IF v_nPos = 0 THEN
    v_tempVar := RIGHT(v_S_VAL, LENGTH(v_S_VAL) - v_oPos + 1);
    ELSE
    v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos FOR v_nPos - v_oPos);
    END IF;
    IF v_nPos_t = 0 THEN
    v_tempVar_t := RIGHT(v_S_VAL_TIME, LENGTH(v_S_VAL_TIME) - v_oPos_t + 1);
    ELSE
    v_tempVar_t := SUBSTRING(v_S_VAL_TIME FROM v_oPos_t FOR v_nPos_t - v_oPos_t);
    END IF;
    IF LENGTH(v_tempVar) > 0 AND LENGTH(v_tempVar_t) > 0 THEN
    v_tempPollId := CAST(v_tempVar AS integer);
    v_tempPlayTime := CAST(v_tempVar_t AS integer);
    INSERT INTO v_PollIDTimeList VALUES (v_tempPollId, v_tempPlayTime);
    END IF;
    v_oPos := v_nPos + 1;
    v_oPos_t := v_nPos_t + 1;
    END IF;
    IF v_nPos = 0 AND v_nPos_t = 0 THEN
    MERGE account_playtime_polls AS app USING v_PollIDTimeList AS pitl ON (app.account_id = p_account_id::integer AND app.poll_id = pitl.poll_id) WHEN MATCHED THEN;
    UPDATE SET app.previous_playtime = app.previous_playtime + pitl.PlayTime WHEN NOT MATCHED THEN;
    INSERT INTO VALUES (p_account_id, pitl.poll_id, pitl.PlayTime);
    RETURN 0;
    ELSE
    RETURN -1;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_getservers

CREATE OR REPLACE FUNCTION ap_getservers(
    p_server_id integer DEFAULT 1
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * FROM aion_myserver;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountCacheDA_SrchHiddenFatigueList

CREATE OR REPLACE FUNCTION gm_accountcacheda_srchhiddenfatiguelist(
    p_world_id integer,
    p_last_login_date varchar(24)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	a.account_id, hidden_fatigue_point, hidden_fatigue_updatetime, hidden_fatigue_npckill, u.last_login_time, u.char_id, u.server_id FROM	account_data a  JOIN ( SELECT	account_id, char_id, last_login_time, server_id, ROW_NUMBER() over (partition by account_id order by last_login_time desc) as LOGIN_TIME_ROWNUM FROM	global_user_data  WHERE	server_id = p_world_id::integer AND		last_login_time >= binary(p_last_login_date) ) u ON a.account_id = u.account_id AND u.LOGIN_TIME_ROWNUM = 1 ORDER BY account_id DESC;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountCacheDA_SrchHiddenFatigueListForExcel

CREATE OR REPLACE FUNCTION gm_accountcacheda_srchhiddenfatiguelistforexcel(
    p_world_id integer,
    p_last_login_date varchar(24)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	a.account_id, hidden_fatigue_point, hidden_fatigue_updatetime, hidden_fatigue_npckill, u.last_login_time, u.char_id, u.server_id FROM	account_data a  JOIN ( SELECT	account_id, char_id, last_login_time, server_id, ROW_NUMBER() over (partition by account_id order by last_login_time desc) as LOGIN_TIME_ROWNUM FROM	global_user_data  WHERE	server_id = p_world_id::integer AND		last_login_time >= binary(p_last_login_date) ) u ON a.account_id = u.account_id AND u.LOGIN_TIME_ROWNUM = 1 ORDER BY account_id DESC;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountDataDA_UpdateHiddenFatiguePoint

CREATE OR REPLACE FUNCTION gm_accountdatada_updatehiddenfatiguepoint(
    p_account_id integer,
    p_hidden_fatigue_point integer,
    p_hidden_fatigue_npckill integer,
    p_hidden_fatigue_updatetime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	account_data SET		hidden_fatigue_point = p_hidden_fatigue_point , hidden_fatigue_npckill = p_hidden_fatigue_npckill , hidden_fatigue_updatetime = p_hidden_fatigue_updatetime WHERE	account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountPackDA_SrchBoardBM

CREATE OR REPLACE FUNCTION gm_accountpackda_srchboardbm(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT game_id, current_pos, visited_pos, last_freecharge_time, last_reset_time, free_dice_remain, paid_dice_remain, paid_reset_remain from user_board_bm  where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountPackDA_SrchHiddenFatigue

CREATE OR REPLACE FUNCTION gm_accountpackda_srchhiddenfatigue(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT hidden_fatigue_point, hidden_fatigue_updatetime, hidden_fatigue_npckill from account_data  where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountPackDA_SrchPackType

CREATE OR REPLACE FUNCTION gm_accountpackda_srchpacktype(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT pack_type, expire_date from account_pack where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_AccountPackDA_SrchTrialAccount

CREATE OR REPLACE FUNCTION gm_accountpackda_srchtrialaccount(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT update_time, reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum from trial_account_data where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_GlobalUserDataDA_UpdateDeleteDate

CREATE OR REPLACE FUNCTION gm_globaluserdatada_updatedeletedate(
    p_delete_date integer,
    p_delete_complete_date integer,
    p_server_id integer,
    p_char_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	global_user_data SET		delete_date = p_delete_date , delete_completed_date = p_delete_complete_date WHERE	server_id = p_server_id::integer AND		char_id = p_char_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_JumpingCharDA_ChangeAllSettingsToDeactivate

CREATE OR REPLACE FUNCTION gm_jumpingcharda_changeallsettingstodeactivate(
    p_is_special_server smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	jumping_character_config SET		is_deleted = 1 WHERE	is_special_server = p_is_special_server;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_JumpingCharDA_Srch

CREATE OR REPLACE FUNCTION gm_jumpingcharda_srch(
    p_is_special_server smallint
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	server_id, is_special_server, start_date, end_date, max_creation_count, required_char_level, is_deleted, login_id, login_nm, reg_date FROM	jumping_character_config  WHERE	is_special_server = p_is_special_server ORDER BY server_id, reg_date DESC;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_JumpingCharDA_UpdateCheckedServerSetting

CREATE OR REPLACE FUNCTION gm_jumpingcharda_updatecheckedserversetting(
    p_server_id integer,
    p_is_special_server smallint,
    p_start_date timestamp,
    p_end_date timestamp,
    p_max_creation_count integer,
    p_required_char_level integer,
    p_is_deleted smallint,
    p_login_id varchar(30),
    p_login_nm varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    UPDATE	jumping_character_config SET		start_date = p_start_date, end_date = p_end_date, max_creation_count = p_max_creation_count, required_char_level = p_required_char_level, is_deleted = p_is_deleted, login_id = p_login_id, login_nm = p_login_nm, reg_date = CURRENT_TIMESTAMP WHERE	server_id = p_server_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF (v_rowcount < 1) THEN
    INSERT INTO jumping_character_config (server_id, is_special_server, start_date, end_date, max_creation_count, required_char_level, is_deleted, login_id, login_nm, reg_date) VALUES (p_server_id, p_is_special_server, p_start_date, p_end_date, p_max_creation_count, p_required_char_level, p_is_deleted, p_login_id, p_login_nm, CURRENT_TIMESTAMP);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LoginEventDA_Srch

CREATE OR REPLACE FUNCTION gm_logineventda_srch(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, account_id, event_id, stamp_count, recent_count_update_date, recent_anniversity_reward_time FROM	user_login_event_data  WHERE	account_id = p_account_id::integer ORDER BY event_id desc, id desc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LoginEventDA_SrchDaily

CREATE OR REPLACE FUNCTION gm_logineventda_srchdaily(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded FROM	user_login_event_data_daily  WHERE	account_id = p_account_id::integer ORDER BY event_id desc, id desc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LoginEventDA_SrchDailyAndOther

CREATE OR REPLACE FUNCTION gm_logineventda_srchdailyandother(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded FROM	user_login_event_data_daily  WHERE	account_id = p_account_id::integer UNION SELECT	id, account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded FROM	user_login_event_data_other  WHERE	account_id = p_account_id::integer ORDER BY event_id desc, id desc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LoginEventDA_SrchOther

CREATE OR REPLACE FUNCTION gm_logineventda_srchother(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, account_id, event_id, valid_login_count, recent_count_update_date, be_rewarded FROM	user_login_event_data_other  WHERE	account_id = p_account_id::integer ORDER BY event_id desc, id desc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LunaInfoListDA_DecreaseLunaAmount

CREATE OR REPLACE FUNCTION gm_lunainfolistda_decreaselunaamount(
    p_accountId integer,
    p_decreaseLunaAmount bigint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_decreaseLunaAmount > 0 THEN
    UPDATE account_luna SET luna = luna - p_decreaseLunaAmount, updatedate = CURRENT_TIMESTAMP WHERE accountId = p_accountId AND luna >= p_decreaseLunaAmount;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LunaInfoListDA_SrchLunaAmount

CREATE OR REPLACE FUNCTION gm_lunainfolistda_srchlunaamount(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	luna, createdate, updatedate FROM	account_luna  WHERE	accountId = p_accountId;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_LunaInfoListDA_SrchLunaReward

CREATE OR REPLACE FUNCTION gm_lunainfolistda_srchlunareward(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	today_reward, remain_reward, key_count, createdate, updatedate FROM	account_luna_reward  WHERE	accountId = p_accountId;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_MonsterCoreDA_DeleteMonsterCoreByAccountId

CREATE OR REPLACE FUNCTION gm_monstercoreda_deletemonstercorebyaccountid(
    p_account_id integer,
    p_monster_core_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM user_monster_core WHERE account_id = p_account_id::integer and core_id = p_monster_core_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_MonsterCoreDA_InsertMonsterCoreByAccountId

CREATE OR REPLACE FUNCTION gm_monstercoreda_insertmonstercorebyaccountid(
    p_account_id integer,
    p_monster_core_id integer,
    p_grade integer,
    p_count integer,
    p_total_added integer,
    p_total_used integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_monster_core (account_id,core_id,core_grade,core_count,total_added,total_used) VALUES (p_account_id,p_monster_core_id,p_grade, p_count, p_total_added, p_total_used);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_MonsterCoreDA_SrchMonsterCoreByAccountId

CREATE OR REPLACE FUNCTION gm_monstercoreda_srchmonstercorebyaccountid(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT id, account_id, core_id, core_grade, core_count FROM user_monster_core  where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_MonsterCoreDA_UpdateMonsterCoreByAccountId

CREATE OR REPLACE FUNCTION gm_monstercoreda_updatemonstercorebyaccountid(
    p_account_id integer,
    p_monster_core_id integer,
    p_grade integer,
    p_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    update user_monster_core set core_grade = p_grade , core_count = p_count where account_id = p_account_id::integer and core_id = p_monster_core_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_TransformDA_DeleteTransformByAccountId

CREATE OR REPLACE FUNCTION gm_transformda_deletetransformbyaccountid(
    p_account_id integer,
    p_transform_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    delete from user_transform where account_id = p_account_id::integer and name_id = p_transform_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_TransformDA_InsertTransformByAccountId

CREATE OR REPLACE FUNCTION gm_transformda_inserttransformbyaccountid(
    p_account_id integer,
    p_transform_id integer,
    p_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO user_transform (account_id,name_id,count,update_time) VALUES (p_account_id,p_transform_id,p_count,CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_TransformDA_SrchTransformByAccountId

CREATE OR REPLACE FUNCTION gm_transformda_srchtransformbyaccountid(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT name_id, count, update_time FROM user_transform  where account_id = p_account_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_TransformDA_UpdateTransformByAccountId

CREATE OR REPLACE FUNCTION gm_transformda_updatetransformbyaccountid(
    p_account_id integer,
    p_transform_id integer,
    p_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE user_transform SET count = p_count::integer, update_time = CURRENT_TIMESTAMP WHERE account_id = p_account_id::integer and name_id = p_transform_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_UserRankingDA_SrchUserListByRankId

CREATE OR REPLACE FUNCTION gm_userrankingda_srchuserlistbyrankid(
    p_rank_id integer,
    p_is_special_server integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  SpecialServerType, RankId, SeasonNumber, TO_CHAR(LastUpdateTime, 'YYYY-MM-DD HH24:MI:SS') LastUpdateTime, SeasonStatus,TableDump, TableVersion FROM	aion_ranking_info  where RankId = p_rank_id and SpecialServerType = p_is_special_server order by Id Desc LIMIT 1;
END;
$$;

-- --------------------------------------------------------

