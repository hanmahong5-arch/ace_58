-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeCosmetic_20151013.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changecosmetic_20151013(_char_id INTEGER, _head_face_color INTEGER, _head_hair_color INTEGER, _eye_color INTEGER, _lip_color INTEGER, _head_face_type INTEGER, _head_hair_type INTEGER, _scale DOUBLE PRECISION, _voice_type INTEGER, _feat_type1 INTEGER, _feat_type2 INTEGER, _head_bump_type INTEGER, _head_expression_type INTEGER, _feat_version INTEGER, _feat_face_shape INTEGER, _feat_forehead_shape INTEGER, _feat_eye_position INTEGER, _feat_eye_glabella INTEGER, _feat_eye_length INTEGER, _feat_eye_height INTEGER, _feat_eye_shape INTEGER, _feat_eye_tail INTEGER, _feat_eyeblow_pos INTEGER, _feat_eyeblow_angle INTEGER, _feat_eyeblow_shape INTEGER, _feat_nose_pos INTEGER, _feat_nose_bridge INTEGER, _feat_nose_side INTEGER, _feat_nose_tip INTEGER, _feat_cheek_shape INTEGER, _feat_mouth_pos INTEGER, _feat_mouth_size INTEGER, _feat_lip_thickness INTEGER, _feat_lip_tail INTEGER, _feat_lip_shape INTEGER, _feat_jaw_pos INTEGER, _feat_jaw_shape INTEGER, _feat_ear_shape INTEGER, _feat_head_size INTEGER, _feat_neck_thickness INTEGER, _feat_neck_length INTEGER, _feat_shoulder_size INTEGER, _feat_upper_size INTEGER, _feat_bust_size INTEGER, _feat_waist_size INTEGER, _feat_hip_size INTEGER, _feat_arm_thickness INTEGER, _feat_hand_size INTEGER, _feat_leg_thickness INTEGER, _feat_foot_size INTEGER, _feat_face_ratio INTEGER, _feat_wing_size INTEGER, _feat_arm_length INTEGER, _feat_leg_length INTEGER, _feat_shoulder_width INTEGER, _feat_head_figure INTEGER, _head_eye_type INTEGER, _head_dark_tail INTEGER, _head_eye_color2 INTEGER, _head_eye_lash INTEGER, _feat_head_eye_size INTEGER, _feat_upper_height INTEGER, _feat_arm_lower_thickness INTEGER, _feat_hand_length INTEGER, _feat_leg_lower_thickness INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- backup history

INSERT INTO user_customize_history (

		char_id

      ,user_id

      ,account_id

      ,account_name

      ,race

      ,class

      ,gender

      ,lev

      ,history_date

      ,head_face_color

      ,head_hair_color

      ,head_eye_color

      ,head_lip_color

      ,head_face_type

      ,head_hair_type

      ,height_scale

      ,head_voice_type

      ,head_feat_type1

      ,head_feat_type2

      ,feat_version

      ,feat_face_shape

      ,feat_forehead_shape

      ,feat_eye_position

      ,feat_eye_glabella

      ,feat_eye_length

      ,feat_eye_height

      ,feat_eye_shape

      ,feat_eye_tail

      ,feat_eyeblow_pos

      ,feat_eyeblow_angle

      ,feat_eyeblow_shape

      ,feat_nose_pos

      ,feat_nose_bridge

      ,feat_nose_side

      ,feat_nose_tip

      ,feat_cheek_shape

      ,feat_mouth_pos

      ,feat_mouth_size

      ,feat_lip_thickness

      ,feat_lip_tail

      ,feat_lip_shape

      ,feat_jaw_pos

      ,feat_jaw_shape

      ,feat_head_size

      ,feat_neck_thickness

      ,feat_neck_length

      ,feat_shoulder_size

      ,feat_upper_size

      ,feat_bust_size

      ,feat_waist_size

      ,feat_hip_size

      ,feat_arm_thickness

      ,feat_hand_size

      ,feat_leg_thickness

      ,feat_foot_size

      ,feat_ear_shape

      ,feat_face_ratio

      ,feat_wing_size

      ,feat_arm_length

      ,feat_leg_length

      ,feat_shoulder_width

	  ,head_bump_type

	  ,head_expression_type

	  ,feat_head_figure

	  ,head_eye_type

	  ,head_dark_tail

	  ,head_eye_color2 

	  ,head_eye_lash

	  ,feat_head_eye_size

	  ,feat_upper_height

	  ,feat_arm_lower_thickness

	  ,feat_hand_length

	  ,feat_leg_lower_thickness

) SELECT char_id

      ,user_id

      ,account_id

      ,account_name

      ,race

      ,class

      ,gender

      ,lev

      ,NOW()

      ,head_face_color

      ,head_hair_color

      ,head_eye_color

      ,head_lip_color

      ,head_face_type

      ,head_hair_type

      ,height_scale

      ,head_voice_type

      ,head_feat_type1

      ,head_feat_type2

      ,feat_version

      ,feat_face_shape

      ,feat_forehead_shape

      ,feat_eye_position

      ,feat_eye_glabella

      ,feat_eye_length

      ,feat_eye_height

      ,feat_eye_shape

      ,feat_eye_tail

      ,feat_eyeblow_pos

      ,feat_eyeblow_angle

      ,feat_eyeblow_shape

      ,feat_nose_pos

      ,feat_nose_bridge

      ,feat_nose_side

      ,feat_nose_tip

      ,feat_cheek_shape

      ,feat_mouth_pos

      ,feat_mouth_size

      ,feat_lip_thickness

      ,feat_lip_tail

      ,feat_lip_shape

      ,feat_jaw_pos

      ,feat_jaw_shape

      ,feat_head_size

      ,feat_neck_thickness

      ,feat_neck_length

      ,feat_shoulder_size

      ,feat_upper_size

      ,feat_bust_size

      ,feat_waist_size

      ,feat_hip_size

      ,feat_arm_thickness

      ,feat_hand_size

      ,feat_leg_thickness

      ,feat_foot_size

      ,feat_ear_shape

      ,feat_face_ratio

      ,feat_wing_size

      ,feat_arm_length

      ,feat_leg_length

      ,feat_shoulder_width

	  ,head_bump_type

	  ,head_expression_type

	  ,feat_head_figure

	  ,head_eye_type

	  ,head_dark_tail

	  ,head_eye_color2 

	  ,head_eye_lash

	  ,feat_head_eye_size

	  ,feat_upper_height

	  ,feat_arm_lower_thickness

	  ,feat_hand_length

	  ,feat_leg_lower_thickness

  FROM user_data

WHERE char_id = _char_id

	

Update user_data 

Set head_face_color = _head_face_color,

	head_hair_color = _head_hair_color, 

	head_eye_color = _eye_color,

	head_lip_color = _lip_color,

	head_face_type = _head_face_type,

	head_hair_type = _head_hair_type,

	height_scale = _scale,

	head_voice_type = _voice_type,

	head_feat_type1 = _feat_type1,

	head_feat_type2 = _feat_type2,

	feat_version = _feat_version,

	feat_face_shape = _feat_face_shape,

	feat_forehead_shape = _feat_forehead_shape,

	feat_eye_position = _feat_eye_position,

	feat_eye_glabella = _feat_eye_glabella,

	feat_eye_length = _feat_eye_length,

	feat_eye_height = _feat_eye_height,

	feat_eye_shape = _feat_eye_shape,

	feat_eye_tail = _feat_eye_tail,

	feat_eyeblow_pos = _feat_eyeblow_pos,

	feat_eyeblow_angle = _feat_eyeblow_angle,

	feat_eyeblow_shape = _feat_eyeblow_shape,

	feat_nose_pos = _feat_nose_pos,

	feat_nose_bridge = _feat_nose_bridge,

	feat_nose_side = _feat_nose_side,

	feat_nose_tip = _feat_nose_tip,

	feat_cheek_shape = _feat_cheek_shape,

	feat_mouth_pos = _feat_mouth_pos,

	feat_mouth_size = _feat_mouth_size,

	feat_lip_thickness = _feat_lip_thickness,

	feat_lip_tail = _feat_lip_tail,

	feat_lip_shape = _feat_lip_shape,

	feat_jaw_pos = _feat_jaw_pos,

	feat_jaw_shape = _feat_jaw_shape,

	feat_ear_shape = _feat_ear_shape,

	feat_head_size = _feat_head_size,

	feat_neck_thickness = _feat_neck_thickness,

	feat_neck_length = _feat_neck_length,

	feat_shoulder_size = _feat_shoulder_size,

	feat_upper_size = _feat_upper_size,

	feat_bust_size = _feat_bust_size,

	feat_waist_size = _feat_waist_size,

	feat_hip_size = _feat_hip_size,

	feat_arm_thickness = _feat_arm_thickness,

	feat_hand_size = _feat_hand_size,

	feat_leg_thickness = _feat_leg_thickness,

	feat_foot_size = _feat_foot_size,

	feat_face_ratio = _feat_face_ratio,

	feat_wing_size = _feat_wing_size,

	feat_arm_length = _feat_arm_length,

	feat_leg_length = _feat_leg_length,

	feat_shoulder_width = _feat_shoulder_width, 

	head_bump_type = _head_bump_type,

	head_expression_type = _head_expression_type,

	feat_head_figure = _feat_head_figure,

	head_eye_type = _head_eye_type,

	head_dark_tail = _head_dark_tail,

	head_eye_color2 = _head_eye_color2, 

	head_eye_lash = _head_eye_lash,

	feat_head_eye_size = _feat_head_eye_size, 

	feat_upper_height = _feat_upper_height,

	feat_arm_lower_thickness = _feat_arm_lower_thickness,

	feat_hand_length = _feat_hand_length,

	feat_leg_lower_thickness = _feat_leg_lower_thickness

WHERE char_id  =  _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changecosmetic_20151013;
-- +goose StatementEnd
