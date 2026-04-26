-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateCustomData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updatecustomdata(_char_id INTEGER, _race INTEGER, _gender BOOLEAN, _name_id INTEGER, _head_face_color INTEGER, _head_hair_color INTEGER, _head_face_type INTEGER, _head_hair_type INTEGER, _head_eye_color INTEGER, _height_scale DOUBLE PRECISION, _head_feat_type1 INTEGER, _head_feat_type2 INTEGER, _feat_face_shape INTEGER, _feat_forehead_shape INTEGER, _feat_eye_position INTEGER, _feat_eye_glabella INTEGER, _feat_eye_length INTEGER, _feat_eye_height INTEGER, _feat_eye_shape INTEGER, _feat_eye_tail INTEGER, _feat_eyeblow_pos INTEGER, _feat_eyeblow_angle INTEGER, _feat_eyeblow_shape INTEGER, _feat_nose_pos INTEGER, _feat_nose_bridge INTEGER, _feat_nose_side INTEGER, _feat_nose_tip INTEGER, _feat_cheek_shape INTEGER, _feat_mouth_pos INTEGER, _feat_mouth_size INTEGER, _feat_lip_thickness INTEGER, _feat_lip_tail INTEGER, _feat_lip_shape INTEGER, _feat_jaw_pos INTEGER, _feat_jaw_shape INTEGER, _feat_head_size INTEGER, _feat_neck_thickness INTEGER, _feat_neck_length INTEGER, _feat_shoulder_size INTEGER, _feat_upper_size INTEGER, _feat_bust_size INTEGER, _feat_waist_size INTEGER, _feat_hip_size INTEGER, _feat_arm_thickness INTEGER, _feat_hand_size INTEGER, _feat_leg_thickness INTEGER, _feat_foot_size INTEGER, _feat_wing_size INTEGER, _feat_version INTEGER, _feat_ear_shape INTEGER, _feat_face_ratio INTEGER, _feat_arm_length INTEGER, _feat_leg_length INTEGER, _head_lip_color INTEGER, _feat_shoulder_width INTEGER, _head_bump_type INTEGER, _head_expression_type INTEGER, _feat_head_figure INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
/*

	exec GM_UserDataDA_UpdateCustomData _char_id=55819, ...

*/

BEGIN



	UPDATE	user_data

	SET		-- user data

			race = _race, 

			gender = _gender,

			name_id = _name_id,

			-- feat

			feat_version = _feat_version, 

			height_scale = _height_scale, --head_voice_type, 

			-- type

			head_hair_type = _head_hair_type, 

			head_face_type = _head_face_type, 

			head_feat_type1 = _head_feat_type1, 

			head_feat_type2 = _head_feat_type2, 

			head_bump_type = _head_bump_type, 

			head_expression_type = _head_expression_type, 

			-- color

			head_hair_color = _head_hair_color, 

			head_lip_color = _head_lip_color, 

			head_eye_color = _head_eye_color, 

			head_face_color = _head_face_color, 

			-- feat_data_enum

			feat_face_shape = _feat_face_shape,	-- 1

			feat_forehead_shape = _feat_forehead_shape, 

			feat_eye_position = _feat_eye_position, 

			feat_eye_glabella = _feat_eye_glabella, 

			feat_eye_length = _feat_eye_length, 

			feat_eye_height = _feat_eye_height, 

			feat_eye_shape = _feat_eye_shape, 

			feat_eye_tail = _feat_eye_tail, 

			feat_eyeblow_pos = _feat_eyeblow_pos, 

			feat_eyeblow_angle = _feat_eyeblow_angle, 

			feat_eyeblow_shape = _feat_eyeblow_shape, -- 11

			feat_nose_pos = _feat_nose_pos, 

			feat_nose_bridge = _feat_nose_bridge, 

			feat_nose_side = _feat_nose_side, 

			feat_nose_tip = _feat_nose_tip, 

			feat_cheek_shape = _feat_cheek_shape, 

			feat_mouth_pos = _feat_mouth_pos, 

			feat_mouth_size = _feat_mouth_size, 

			feat_lip_thickness = _feat_lip_thickness, 

			feat_lip_tail = _feat_lip_tail, 

			feat_lip_shape = _feat_lip_shape,  -- 21

			feat_jaw_pos = _feat_jaw_pos, 

			feat_jaw_shape = _feat_jaw_shape, 

			feat_ear_shape = _feat_ear_shape, 

			feat_head_size = _feat_head_size, 

			feat_neck_thickness = _feat_neck_thickness, 

			feat_neck_length = _feat_neck_length, 

			feat_shoulder_size = _feat_shoulder_size, 

			feat_upper_size = _feat_upper_size, 

			feat_bust_size = _feat_bust_size, 

			feat_waist_size = _feat_waist_size,	-- 31

			feat_hip_size = _feat_hip_size, 

			feat_arm_thickness = _feat_arm_thickness, 

			feat_hand_size = _feat_hand_size, 

			feat_leg_thickness = _feat_leg_thickness, 

			feat_foot_size = _feat_foot_size, 

			feat_face_ratio = _feat_face_ratio, 

			feat_wing_size = _feat_wing_size, 

			feat_arm_length = _feat_arm_length, 

			feat_leg_length = _feat_leg_length, 

			feat_shoulder_width = _feat_shoulder_width,	-- 41

			feat_head_figure = _feat_head_figure



	WHERE	char_id = _char_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updatecustomdata;
-- +goose StatementEnd
