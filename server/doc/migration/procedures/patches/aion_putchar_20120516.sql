-- database: aion_world_live
CREATE OR REPLACE FUNCTION aion_putchar_20120516(
    p_strUserId varchar(20),
    p_nAccountID integer,
    p_strAccountName varchar(14),
    p_nRace smallint,
    p_nClass smallint,
    p_nGender integer,
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
    p_nNameId integer,
    p_nOrgServer smallint,
    p_nWorld integer,
    p_nXlocation real,
    p_nYlocation real,
    p_nZlocation real,
    p_nDir smallint,
    p_nHp integer,
    p_nMp integer,
    p_nBuilder smallint,
    p_feat_version smallint,
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
    p_feat_head_figure smallint,
    OUT p_CreateTime varchar(30),
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_CURR_TIME timestamp;
BEGIN
    v_CURR_TIME := CURRENT_TIMESTAMP;
    p_CreateTime := CAST(v_CURR_TIME AS varchar(30));
    IF IDENT_CURRENT('user_data') > 33550000 THEN
    p_return_code := -1;
    RETURN;
    END IF;
    IF EXISTS (SELECT char_id FROM user_data WHERE user_id = p_strUserId::integer AND (delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),0)))) THEN
    p_return_code := -1;
    RETURN;
    END IF;
    IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE FORBIDDEN_WORD = p_strUserId and IS_LIKE = 0 and status=0 and (forbidden_type=0 or forbidden_type=1)) THEN
    p_return_code := -2;
    RETURN;
    END IF;
    IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_word WHERE (p_strUserId LIKE '%' || FORBIDDEN_WORD || '%') and forbidden_word <> '' and IS_LIKE = 1 and status=0 and (forbidden_type=1 or forbidden_type=0)) THEN
    p_return_code := -2;
    RETURN;
    END IF;
    IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=p_strUserId and status=0 and (forbidden_reason in (3,4)) and ((EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (regdate)::timestamp) / 86400)::integer < 366)) THEN
    p_return_code := -2;
    RETURN;
    END IF;
    IF EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=p_strUserId and status=0 and forbidden_reason = 2) THEN
    IF NOT EXISTS (SELECT FORBIDDEN_ID FROM forbidden_char WHERE FORBIDDEN_CHAR=p_strUserId and FORBIDDEN_ACCOUNT_NM=p_strAccountName and status=0 and forbidden_reason = 2) THEN
    p_return_code := -3;
    RETURN;
    END IF;
    END IF;
    INSERT INTO user_data (user_id,account_id, account_name, race, class, gender, head_face_color, head_hair_color, head_eye_color, head_lip_color, head_face_type, head_hair_type, height_scale, head_voice_type, head_feat_type1, head_feat_type2, head_bump_type, head_expression_type, name_id, guild_id, guild_rank, jobfaction_id, jobfaction_rank, jobfaction_friendship, npcfaction_id, npcfaction_rank, org_server, cur_server, world,xlocation,ylocation, zlocation, dir, builder, now_hit, now_mana, is_banned, exp,abyss_point,lev,stigmaPoint, guild_intro,guild_nickname, event, create_date, cur_title_id, petition_msg, daily_comment, feat_version, feat_face_shape, feat_forehead_shape, feat_eye_position, feat_eye_glabella, feat_eye_length, feat_eye_height, feat_eye_shape, feat_eye_tail, feat_eyeblow_pos, feat_eyeblow_angle, feat_eyeblow_shape, feat_nose_pos, feat_nose_bridge, feat_nose_side, feat_nose_tip, feat_cheek_shape, feat_mouth_pos, feat_mouth_size, feat_lip_thickness, feat_lip_tail, feat_lip_shape, feat_jaw_pos, feat_jaw_shape, feat_ear_shape, feat_head_size, feat_neck_thickness, feat_neck_length, feat_shoulder_size, feat_upper_size, feat_bust_size, feat_waist_size, feat_hip_size, feat_arm_thickness, feat_hand_size, feat_leg_thickness, feat_foot_size, feat_face_ratio, feat_wing_size, feat_arm_length, feat_leg_length, feat_shoulder_width, feat_head_figure, change_info_time ) VALUES (p_strUserId, p_nAccountID, p_strAccountName, p_nRace, p_nClass, p_nGender::boolean, p_nHeadFaceColor, p_nHeadHairColor, p_nEyeColor, p_nLipColor, p_nHeadFaceType, p_nHeadHairType, p_fScale, p_nVoiceType, p_nFeatType1, p_nFeatType2, p_nHeadBumpType, p_nHeadExpressionType, p_nNameId, 0, 2, 0,0,0,0,0, p_nOrgServer, p_nOrgServer, p_nWorld, p_nXlocation, p_nYlocation, p_nZlocation, p_nDir, p_nBuilder, p_nHp, p_nMp, 0, 0,0,1,0,'', '', 0, v_CURR_TIME, 0, '', '', p_feat_version, p_feat_face_shape, p_feat_forehead_shape, p_feat_eye_position, p_feat_eye_glabella, p_feat_eye_length, p_feat_eye_height, p_feat_eye_shape, p_feat_eye_tail, p_feat_eyeblow_pos, p_feat_eyeblow_angle, p_feat_eyeblow_shape, p_feat_nose_pos, p_feat_nose_bridge, p_feat_nose_side, p_feat_nose_tip, p_feat_cheek_shape, p_feat_mouth_pos, p_feat_mouth_size, p_feat_lip_thickness, p_feat_lip_tail, p_feat_lip_shape, p_feat_jaw_pos, p_feat_jaw_shape, p_feat_ear_shape, p_feat_head_size, p_feat_neck_thickness, p_feat_neck_length, p_feat_shoulder_size, p_feat_upper_size, p_feat_bust_size, p_feat_waist_size, p_feat_hip_size, p_feat_arm_thickness, p_feat_hand_size, p_feat_leg_thickness, p_feat_foot_size, p_feat_face_ratio, p_feat_wing_size, p_feat_arm_length, p_feat_leg_length, p_feat_shoulder_width, p_feat_head_figure, GetUnixtimeWithUTCAdjust((CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),0) );
    IF 0 /* @v_ERROR */ <> 0 THEN
    p_return_code := 0;
    RETURN;
    END IF;
    p_return_code := 0;
        -- RETURN_EXPR: LASTVAL();
END;
$$;
