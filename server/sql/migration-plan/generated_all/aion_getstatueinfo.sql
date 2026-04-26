-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetStatueInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getstatueinfo()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT B.npc_name_id, B.char_id, user_id, race, gender, height_scale,

	head_face_color, head_hair_color, head_eye_color, head_lip_color, head_face_type, head_hair_type, head_feat_type1, head_feat_type2, COALESCE(head_bump_type, 0), COALESCE(head_expression_type, 0),

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

	COALESCE(feat_head_figure, 0),

	COALESCE(head_eye_type, 0),

	COALESCE(head_dark_tail, 1),

	COALESCE(head_eye_color2, 0), 

	COALESCE(head_eye_lash, 0),

	COALESCE(feat_head_eye_size, 0), 

	COALESCE(feat_upper_height, 0),

	COALESCE(feat_arm_lower_thickness, 0),

	COALESCE(feat_hand_length, 0),

	COALESCE(feat_leg_lower_thickness, 0),

	COALESCE(C.name_id, 0) AS keyblade_name_id		-- 키블레이드 네임아이디



FROM user_data AS A INNER JOIN statue_info AS B

ON A.char_id = B.char_id 

LEFT OUTER JOIN user_item AS C

ON A.char_id = C.char_id AND 102100000 <= C.name_id AND C.name_id <= 102199999

AND C.slot = 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getstatueinfo;
-- +goose StatementEnd
