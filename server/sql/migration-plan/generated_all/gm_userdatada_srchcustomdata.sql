-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCustomData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcustomdata(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	set ansi_warnings off



	SELECT	char_id, user_id, race, class, gender, org_server,	-- user data

			-- feat

			feat_version, 

			height_scale, --head_voice_type, 

			-- type

			head_hair_type, head_face_type, head_feat_type1, head_feat_type2, head_bump_type, head_expression_type, 

			-- colior

			head_hair_color, head_lip_color, head_eye_color, head_face_color, 

			-- feat_data_enum

			feat_face_shape, feat_forehead_shape, feat_eye_position, feat_eye_glabella, feat_eye_length, 

			feat_eye_height, feat_eye_shape, feat_eye_tail, feat_eyeblow_pos, feat_eyeblow_angle, 

			feat_eyeblow_shape, feat_nose_pos, feat_nose_bridge, feat_nose_side, feat_nose_tip, 

			feat_cheek_shape, feat_mouth_pos, feat_mouth_size, feat_lip_thickness, feat_lip_tail, 

			feat_lip_shape, feat_jaw_pos, feat_jaw_shape, feat_ear_shape, feat_head_size, 

			feat_neck_thickness, feat_neck_length, feat_shoulder_size, feat_upper_size, feat_bust_size, 

			feat_waist_size, feat_hip_size, feat_arm_thickness, feat_hand_size, feat_leg_thickness, 

			feat_foot_size, feat_face_ratio, feat_wing_size, feat_arm_length, feat_leg_length, 

			feat_shoulder_width, feat_head_figure

	FROM	user_data (nolock)

	WHERE	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcustomdata;
-- +goose StatementEnd
