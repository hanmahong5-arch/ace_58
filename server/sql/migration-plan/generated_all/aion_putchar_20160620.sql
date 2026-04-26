-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutChar_20160620.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putchar_20160620(_create_time TEXT, _user_id TEXT, _account_i_d INTEGER, _account_name TEXT, _race INTEGER, _class INTEGER, _gender INTEGER, _head_face_color INTEGER, _head_hair_color INTEGER, _eye_color INTEGER, _lip_color INTEGER, _head_face_type INTEGER, _head_hair_type INTEGER, _scale DOUBLE PRECISION, _voice_type INTEGER, _feat_type1 INTEGER, _feat_type2 INTEGER, _head_bump_type INTEGER, _head_expression_type INTEGER, _name_id INTEGER, _org_server INTEGER, _world INTEGER, _xlocation DOUBLE PRECISION, _ylocation DOUBLE PRECISION, _zlocation DOUBLE PRECISION, _dir INTEGER, _hp INTEGER, _mp INTEGER, _builder INTEGER, _lev INTEGER, _resurrect_world INTEGER, _resurrect_xlocation DOUBLE PRECISION, _resurrect_ylocation DOUBLE PRECISION, _resurrect_zlocation DOUBLE PRECISION, _inventory_growth INTEGER, _feat_version INTEGER, _feat_face_shape INTEGER, _feat_forehead_shape INTEGER, _feat_eye_position INTEGER, _feat_eye_glabella INTEGER, _feat_eye_length INTEGER, _feat_eye_height INTEGER, _feat_eye_shape INTEGER, _feat_eye_tail INTEGER, _feat_eyeblow_pos INTEGER, _feat_eyeblow_angle INTEGER, _feat_eyeblow_shape INTEGER, _feat_nose_pos INTEGER, _feat_nose_bridge INTEGER, _feat_nose_side INTEGER, _feat_nose_tip INTEGER, _feat_cheek_shape INTEGER, _feat_mouth_pos INTEGER, _feat_mouth_size INTEGER, _feat_lip_thickness INTEGER, _feat_lip_tail INTEGER, _feat_lip_shape INTEGER, _feat_jaw_pos INTEGER, _feat_jaw_shape INTEGER, _feat_ear_shape INTEGER, _feat_head_size INTEGER, _feat_neck_thickness INTEGER, _feat_neck_length INTEGER, _feat_shoulder_size INTEGER, _feat_upper_size INTEGER, _feat_bust_size INTEGER, _feat_waist_size INTEGER, _feat_hip_size INTEGER, _feat_arm_thickness INTEGER, _feat_hand_size INTEGER, _feat_leg_thickness INTEGER, _feat_foot_size INTEGER, _feat_face_ratio INTEGER, _feat_wing_size INTEGER, _feat_arm_length INTEGER, _feat_leg_length INTEGER, _feat_shoulder_width INTEGER, _feat_head_figure INTEGER, _head_eye_type INTEGER, _head_dark_tail INTEGER, _head_eye_color2 INTEGER, _head_eye_lash INTEGER, _feat_head_eye_size INTEGER, _feat_upper_height INTEGER, _feat_arm_lower_thickness INTEGER, _feat_hand_length INTEGER, _feat_leg_lower_thickness INTEGER, _is_jumping_character INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	

DECLARE _c_u_r_r__t_i_m_e DateTime

_c_u_r_r__t_i_m_e := NOW()



--DECLARE _u_t_c__a_d_j_u_s_t INT

--_u_t_c__a_d_j_u_s_t := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), _c_u_r_r__t_i_m_e)

--_create_time := GetUnixtimeWithUTCAdjust(_c_u_r_r__t_i_m_e, _u_t_c__a_d_j_u_s_t)

_create_time := convert(nvarchar(30), _c_u_r_r__t_i_m_e, 126) 

	

-- 유저캐릭터아이디가 경계에 도달할때 캐릭터생성금지

IF IDENT_CURRENT('user_data') > 33550000

	return -1



-- 유효한 이름인지 검사

declare _check_valid_char_name int

exec _check_valid_char_name = aion_CheckValidCharName

	_name = _user_id,

	_account = _account_name



if _check_valid_char_name <> 0

	return _check_valid_char_name





INSERT user_data (user_id,account_id, account_name, race, class, gender, 

	head_face_color, head_hair_color, head_eye_color, head_lip_color, head_face_type, head_hair_type, height_scale, head_voice_type, head_feat_type1, head_feat_type2,

	head_bump_type, head_expression_type,

	name_id, guild_id, guild_rank, 

	jobfaction_id, jobfaction_rank, jobfaction_friendship, npcfaction_id, npcfaction_rank,

	org_server, cur_server,

	world,xlocation,ylocation, zlocation, dir, 

	builder,	

	now_hit, now_mana,

	lev, resurrect_world, resurrect_xlocation, resurrect_ylocation, resurrect_zlocation, inventory_growth,

	is_banned,	

	exp,abyss_point,stigmaPoint, guild_intro,guild_nickname, 

	event,	

	create_date,

	cur_title_id, 

	petition_msg,

	daily_comment,

	feat_version,

	feat_face_shape,

	feat_forehead_shape,

	feat_eye_position,

	feat_eye_glabella,

	feat_eye_length,

	feat_eye_height,

	feat_eye_shape,

	feat_eye_tail,

	feat_eyeblow_pos,

	feat_eyeblow_angle,

	feat_eyeblow_shape,

	feat_nose_pos,

	feat_nose_bridge,

	feat_nose_side,

	feat_nose_tip,

	feat_cheek_shape,

	feat_mouth_pos,

	feat_mouth_size,

	feat_lip_thickness,

	feat_lip_tail,

	feat_lip_shape,

	feat_jaw_pos,

	feat_jaw_shape,

	feat_ear_shape,

	feat_head_size,

	feat_neck_thickness,

	feat_neck_length,

	feat_shoulder_size,

	feat_upper_size,

	feat_bust_size,

	feat_waist_size,

	feat_hip_size,

	feat_arm_thickness,

	feat_hand_size,

	feat_leg_thickness,

	feat_foot_size,

	feat_face_ratio,

	feat_wing_size,

	feat_arm_length,

	feat_leg_length,

	feat_shoulder_width,

	feat_head_figure,

	change_info_time,

	head_eye_type,

	head_dark_tail,

	head_eye_color2, 

	head_eye_lash,

	feat_head_eye_size, 

	feat_upper_height,

	feat_arm_lower_thickness,

	feat_hand_length,

	feat_leg_lower_thickness,

	is_jumping_character

)

 VALUES (_user_id, _account_i_d, _account_name, _race, _class, _gender, 

	_head_face_color, _head_hair_color, _eye_color, _lip_color, _head_face_type, _head_hair_type, _scale, _voice_type, _feat_type1, _feat_type2,

	_head_bump_type, _head_expression_type,

	_name_id, 0, 2, 

	0,0,0,0,0,

	_org_server, _org_server,

	_world, _xlocation, _ylocation, _zlocation, _dir,

	_builder,	

	_hp, _mp,

	_lev, _resurrect_world, _resurrect_xlocation, _resurrect_ylocation, _resurrect_zlocation, _inventory_growth,

	0, -- is_banned	

	0,0,0,'', '', -- exp, abyss_point, stigmaPoint, guild_intro, guild_nickname

	0, -- event,		

	_c_u_r_r__t_i_m_e,

	0, 

	'',-- create_date,petition_msg

	'',-- daily_comment

	_feat_version,

	_feat_face_shape,

	_feat_forehead_shape,

	_feat_eye_position,

	_feat_eye_glabella,

	_feat_eye_length,

	_feat_eye_height,

	_feat_eye_shape,

	_feat_eye_tail,

	_feat_eyeblow_pos,

	_feat_eyeblow_angle,

	_feat_eyeblow_shape,

	_feat_nose_pos,

	_feat_nose_bridge,

	_feat_nose_side,

	_feat_nose_tip,

	_feat_cheek_shape,

	_feat_mouth_pos,

	_feat_mouth_size,

	_feat_lip_thickness,

	_feat_lip_tail,

	_feat_lip_shape,

	_feat_jaw_pos,

	_feat_jaw_shape,

	_feat_ear_shape,

	_feat_head_size,

	_feat_neck_thickness,

	_feat_neck_length,

	_feat_shoulder_size,

	_feat_upper_size,

	_feat_bust_size,

	_feat_waist_size,

	_feat_hip_size,

	_feat_arm_thickness,

	_feat_hand_size,

	_feat_leg_thickness,

	_feat_foot_size,

	_feat_face_ratio,

	_feat_wing_size,

	_feat_arm_length,

	_feat_leg_length,

	_feat_shoulder_width,

	_feat_head_figure,

	GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0),

	_head_eye_type,

	_head_dark_tail,

	_head_eye_color2, 

	_head_eye_lash,

	_feat_head_eye_size, 

	_feat_upper_height,

	_feat_arm_lower_thickness,

	_feat_hand_length,

	_feat_leg_lower_thickness,

	_is_jumping_character

)




 IF @_e_r_r_o_r <> 0

	return 0



return @_i_d_e_n_t_i_t_y

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchar_20160620;
-- +goose StatementEnd
