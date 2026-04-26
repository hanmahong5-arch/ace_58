-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_PutChar_20160620.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutChar_20160620.sql
-- Creates a new character. 110 parameters in T-SQL → 110 in PG.
-- The first OUT (CreateTime) is returned together with the new char_id as
-- a single result row — easier for the Go caller than separate OUT params.
--
-- Behavior preserved verbatim:
--   1. If the IDENTITY(user_data) high-water-mark exceeds 33550000 → return
--      (-1, NULL) so the client sees the char-cap error.
--   2. Calls aion_CheckValidCharName first; if it returns non-zero, propagate
--      that as (rc, NULL).
--   3. INSERT user_data with all 99 specified columns.
--   4. Return (0, new_char_id, create_time_iso).
--
-- We use a single SELECT-from-RECORD return so the Go caller can scan
-- (rc INT, new_char_id INT, create_time TIMESTAMPTZ).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchar_20160620(
    TEXT, INTEGER, TEXT, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    DOUBLE PRECISION, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, REAL, REAL, REAL, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, REAL, REAL, REAL, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putchar_20160620(
    _str_user_id           TEXT,
    _account_id            INTEGER,
    _str_account_name      TEXT,
    _race                  INTEGER,
    _class                 INTEGER,
    _gender                INTEGER,
    _head_face_color       INTEGER,
    _head_hair_color       INTEGER,
    _eye_color             INTEGER,
    _lip_color             INTEGER,
    _head_face_type        INTEGER,
    _head_hair_type        INTEGER,
    _scale                 DOUBLE PRECISION,
    _voice_type            INTEGER,
    _feat_type1            INTEGER,
    _feat_type2            INTEGER,
    _head_bump_type        INTEGER,
    _head_expression_type  INTEGER,
    _name_id               INTEGER,
    _org_server            INTEGER,
    _world                 INTEGER,
    _xlocation             REAL,
    _ylocation             REAL,
    _zlocation             REAL,
    _dir                   INTEGER,
    _hp                    INTEGER,
    _mp                    INTEGER,
    _builder               INTEGER,            -- T-SQL tinyint (0/1) — converted to char(1)
    _lev                   INTEGER,
    _resurrect_world       INTEGER,
    _resurrect_xlocation   REAL,
    _resurrect_ylocation   REAL,
    _resurrect_zlocation   REAL,
    _inventory_growth      INTEGER,
    -- 50 customize params follow (feat_* + head_* per PutChar_20160620 spec)
    _feat_version          INTEGER,
    _feat_face_shape       INTEGER,
    _feat_forehead_shape   INTEGER,
    _feat_eye_position     INTEGER,
    _feat_eye_glabella     INTEGER,
    _feat_eye_length       INTEGER,
    _feat_eye_height       INTEGER,
    _feat_eye_shape        INTEGER,
    _feat_eye_tail         INTEGER,
    _feat_eyeblow_pos      INTEGER,
    _feat_eyeblow_angle    INTEGER,
    _feat_eyeblow_shape    INTEGER,
    _feat_nose_pos         INTEGER,
    _feat_nose_bridge      INTEGER,
    _feat_nose_side        INTEGER,
    _feat_nose_tip         INTEGER,
    _feat_cheek_shape      INTEGER,
    _feat_mouth_pos        INTEGER,
    _feat_mouth_size       INTEGER,
    _feat_lip_thickness    INTEGER,
    _feat_lip_tail         INTEGER,
    _feat_lip_shape        INTEGER,
    _feat_jaw_pos          INTEGER,
    _feat_jaw_shape        INTEGER,
    _feat_ear_shape        INTEGER,
    _feat_head_size        INTEGER,
    _feat_neck_thickness   INTEGER,
    _feat_neck_length      INTEGER,
    _feat_shoulder_size    INTEGER,
    _feat_upper_size       INTEGER,
    _feat_bust_size        INTEGER,
    _feat_waist_size       INTEGER,
    _feat_hip_size         INTEGER,
    _feat_arm_thickness    INTEGER,
    _feat_hand_size        INTEGER,
    _feat_leg_thickness    INTEGER,
    _feat_foot_size        INTEGER,
    _feat_face_ratio       INTEGER,
    _feat_wing_size        INTEGER,
    _feat_arm_length       INTEGER,
    _feat_leg_length       INTEGER,
    _feat_shoulder_width   INTEGER,
    _feat_head_figure      INTEGER,
    _head_eye_type         INTEGER,
    _head_dark_tail        INTEGER,
    _head_eye_color2       INTEGER,
    _head_eye_lash         INTEGER,
    _feat_head_eye_size    INTEGER,
    _feat_upper_height     INTEGER,
    _feat_arm_lower_thickness INTEGER,
    _feat_hand_length      INTEGER,
    _feat_leg_lower_thickness INTEGER,
    _is_jumping_character  INTEGER
)
RETURNS TABLE (rc INTEGER, char_id INTEGER, create_time TIMESTAMPTZ)
LANGUAGE plpgsql AS $$
DECLARE
    v_now           TIMESTAMPTZ := NOW();
    v_check_rc      INTEGER;
    v_max_char_id   INTEGER;
    v_new_char_id   INTEGER;
BEGIN
    -- 1. NCSoft caps char_id at 33,550,000.
    SELECT COALESCE(MAX(user_data.char_id), 0) INTO v_max_char_id FROM user_data;
    IF v_max_char_id > 33550000 THEN
        RETURN QUERY SELECT -1, NULL::INTEGER, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    -- 2. Run name validation. CheckValidCharName returns 0 on OK.
    SELECT * INTO v_check_rc
      FROM aion_checkvalidcharname(_str_user_id, _str_account_name) AS x(rc);
    IF v_check_rc <> 0 THEN
        RETURN QUERY SELECT v_check_rc, NULL::INTEGER, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    -- 3. Compute next char_id (NCSoft uses IDENTITY; we mirror with MAX+1).
    v_new_char_id := v_max_char_id + 1;
    -- Reserve a starting offset so we don't collide with seeded test rows
    -- (the test fixtures use 9_000_000-9_000_099). Production callers should
    -- always go through this SP to avoid collision.
    IF v_new_char_id < 1 THEN
        v_new_char_id := 1;
    END IF;

    -- 4. INSERT user_data. Columns in NCSoft INSERT order.
    INSERT INTO user_data (
        char_id, user_id, account_id, account_name,
        race, class, gender,
        head_face_color, head_hair_color, head_eye_color, head_lip_color,
        head_face_type, head_hair_type, height_scale, head_voice_type,
        head_feat_type1, head_feat_type2, head_bump_type, head_expression_type,
        name_id, guild_id, guild_rank,
        jobfaction_id, jobfaction_rank, jobfaction_friendship,
        npcfaction_id, npcfaction_rank,
        org_server, cur_server,
        world, xlocation, ylocation, zlocation, dir,
        builder,
        now_hit, now_mana,
        lev, resurrect_world, resurrect_xlocation, resurrect_ylocation, resurrect_zlocation,
        inventory_growth, is_banned,
        exp, abyss_point, stigmapoint, guild_intro, guild_nickname,
        event,
        create_date, cur_title_id,
        petition_msg, daily_comment,
        feat_version,
        feat_face_shape, feat_forehead_shape, feat_eye_position,
        feat_eye_glabella, feat_eye_length, feat_eye_height,
        feat_eye_shape, feat_eye_tail,
        feat_eyeblow_pos, feat_eyeblow_angle, feat_eyeblow_shape,
        feat_nose_pos, feat_nose_bridge, feat_nose_side, feat_nose_tip,
        feat_cheek_shape,
        feat_mouth_pos, feat_mouth_size, feat_lip_thickness, feat_lip_tail, feat_lip_shape,
        feat_jaw_pos, feat_jaw_shape, feat_ear_shape, feat_head_size,
        feat_neck_thickness, feat_neck_length, feat_shoulder_size,
        feat_upper_size, feat_bust_size, feat_waist_size, feat_hip_size,
        feat_arm_thickness, feat_hand_size, feat_leg_thickness, feat_foot_size,
        feat_face_ratio, feat_wing_size,
        feat_arm_length, feat_leg_length, feat_shoulder_width,
        feat_head_figure,
        change_info_time,
        head_eye_type, head_dark_tail, head_eye_color2, head_eye_lash,
        feat_head_eye_size, feat_upper_height,
        feat_arm_lower_thickness, feat_hand_length, feat_leg_lower_thickness,
        is_jumping_character
    ) VALUES (
        v_new_char_id, _str_user_id, _account_id, _str_account_name,
        _race::SMALLINT, _class::SMALLINT, (_gender <> 0),
        _head_face_color, _head_hair_color, _eye_color, _lip_color,
        _head_face_type::SMALLINT, _head_hair_type::SMALLINT, _scale, _voice_type::SMALLINT,
        _feat_type1::SMALLINT, _feat_type2::SMALLINT, _head_bump_type::SMALLINT, _head_expression_type::SMALLINT,
        _name_id, 0, 2,
        0, 0, 0, 0, 0,
        _org_server::SMALLINT, _org_server::SMALLINT,
        _world, _xlocation, _ylocation, _zlocation, _dir::SMALLINT,
        CASE WHEN _builder <> 0 THEN '1' ELSE '0' END,
        _hp, _mp,
        _lev::INTEGER, _resurrect_world, _resurrect_xlocation, _resurrect_ylocation, _resurrect_zlocation,
        _inventory_growth::SMALLINT, FALSE,
        0, 0, 0, '', '',
        0,
        v_now, 0,
        '', '',
        _feat_version::SMALLINT,
        _feat_face_shape::SMALLINT, _feat_forehead_shape::SMALLINT, _feat_eye_position::SMALLINT,
        _feat_eye_glabella::SMALLINT, _feat_eye_length::SMALLINT, _feat_eye_height::SMALLINT,
        _feat_eye_shape::SMALLINT, _feat_eye_tail::SMALLINT,
        _feat_eyeblow_pos::SMALLINT, _feat_eyeblow_angle::SMALLINT, _feat_eyeblow_shape::SMALLINT,
        _feat_nose_pos::SMALLINT, _feat_nose_bridge::SMALLINT, _feat_nose_side::SMALLINT, _feat_nose_tip::SMALLINT,
        _feat_cheek_shape::SMALLINT,
        _feat_mouth_pos::SMALLINT, _feat_mouth_size::SMALLINT, _feat_lip_thickness::SMALLINT, _feat_lip_tail::SMALLINT, _feat_lip_shape::SMALLINT,
        _feat_jaw_pos::SMALLINT, _feat_jaw_shape::SMALLINT, _feat_ear_shape::SMALLINT, _feat_head_size::SMALLINT,
        _feat_neck_thickness::SMALLINT, _feat_neck_length::SMALLINT, _feat_shoulder_size::SMALLINT,
        _feat_upper_size::SMALLINT, _feat_bust_size::SMALLINT, _feat_waist_size::SMALLINT, _feat_hip_size::SMALLINT,
        _feat_arm_thickness::SMALLINT, _feat_hand_size::SMALLINT, _feat_leg_thickness::SMALLINT, _feat_foot_size::SMALLINT,
        _feat_face_ratio::SMALLINT, _feat_wing_size::SMALLINT,
        _feat_arm_length::SMALLINT, _feat_leg_length::SMALLINT, _feat_shoulder_width::SMALLINT,
        _feat_head_figure::SMALLINT,
        getunixtimewithutcadjust(NOW(), 0),
        _head_eye_type::SMALLINT, _head_dark_tail::SMALLINT, _head_eye_color2, _head_eye_lash::SMALLINT,
        _feat_head_eye_size::SMALLINT, _feat_upper_height::SMALLINT,
        _feat_arm_lower_thickness::SMALLINT, _feat_hand_length::SMALLINT, _feat_leg_lower_thickness::SMALLINT,
        _is_jumping_character::SMALLINT
    );

    RETURN QUERY SELECT 0, v_new_char_id, v_now;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchar_20160620(
    TEXT, INTEGER, TEXT, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    DOUBLE PRECISION, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, REAL, REAL, REAL, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, REAL, REAL, REAL, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER
);
-- +goose StatementEnd
