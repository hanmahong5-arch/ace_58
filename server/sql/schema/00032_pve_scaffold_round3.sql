-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) PvE scaffold round 3.
--
-- Extends 00008_pve_scaffold_round2.sql with the schema surface required by
-- the Round 6 SP batch (PutChar / GetCharInfo / SetCharInfo / GetCharBuilder
-- / SetQuest / DeleteQuest / PutFinishedQuestSimple / GetItemList /
-- SetItemEnchant / GetSkillCooltime / PutSkillCooltime / PutSkillSkin +
-- 7 Priority-B mail/guild SPs).
--
-- Why this is needed: PutChar_20160620 has 110 input parameters and writes
-- 99 face/feat/visual columns to user_data; GetCharInfo_20160818 reads 120
-- columns. Round 6 SPs also touch user_finished_quest (new), reshape
-- user_skill_cooltime (varbinary form) + user_skill_skin (use_skin form),
-- and extend user_item / user_item_option with NCSoft fields used by
-- SetItemEnchant_20180615 (wardrobeSlotId, equipLevelDown, randomAttr/Value
-- 1..10, skill_skin_name_Id) and GetItemList_20120102 (export_id).
--
-- Type translation (T-SQL → PG):
--   tinyint     → SMALLINT
--   bit         → BOOLEAN
--   smallint    → SMALLINT
--   real / float→ REAL / DOUBLE PRECISION
--   varchar(N)  → VARCHAR(N)  (we use TEXT for nvarchar where length is loose)
--   datetime    → TIMESTAMPTZ
--   varbinary   → BYTEA
--   bigint      → BIGINT

-- +goose Up

-- +goose StatementBegin
-- ====================================================================
-- 1. user_data — add the 99 face/feat/visual + abyss/serial/housing
--    columns the PutChar_20160620 INSERT and GetCharInfo_20160818 SELECT
--    touch. Ordered roughly by NCSoft column ordinal for diffability.
-- ====================================================================
ALTER TABLE user_data
    -- identity / lookup
    ADD COLUMN IF NOT EXISTS race                          SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS class                         SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gender                        BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_banned                     BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS name_id                       INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS guild_nickname                TEXT         NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS recreate_guild_time           INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS org_server                    SMALLINT     NOT NULL DEFAULT 0,
    -- Geometry / world
    ADD COLUMN IF NOT EXISTS world_map_number              INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_normal_world             INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_normal_xlocation         REAL         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_normal_ylocation         REAL         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_normal_zlocation         REAL         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_normal_dir               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS death_count                   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS temporary_lost_exp            BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS resurrect_world               INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS resurrect_xlocation           REAL         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS resurrect_ylocation           REAL         NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS resurrect_zlocation           REAL         NOT NULL DEFAULT 0,
    -- Vitals / progression
    ADD COLUMN IF NOT EXISTS builder                       CHAR(1)      NOT NULL DEFAULT '0',
    ADD COLUMN IF NOT EXISTS now_hit                       INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS now_mana                      INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS now_flight                    INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS abyss_point                   BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS abyss_point_from_user         BIGINT       NOT NULL DEFAULT 0,
    -- Stigma / abyss
    ADD COLUMN IF NOT EXISTS stigmapoint                   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS event                         INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS create_date                   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS petition_msg                  TEXT,
    ADD COLUMN IF NOT EXISTS jobfaction_id                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS jobfaction_rank               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS jobfaction_friendship         INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS npcfaction_id                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS npcfaction_rank               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cur_title_id                  INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cur_title_attr_id             INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fly_gauge                     INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS max_fly_gauge                 INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fly_cool_time                 INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS inventory_growth              SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS char_warehouse_growth         SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS daily_comment                 TEXT         NOT NULL DEFAULT '',
    -- Visual: head & color
    ADD COLUMN IF NOT EXISTS head_face_color               INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_hair_color               INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_face_type                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_hair_type                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_lip_color                INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_eye_color                INTEGER      NOT NULL DEFAULT -1,  -- 0xFFFFFFFF default
    ADD COLUMN IF NOT EXISTS height_scale                  DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    ADD COLUMN IF NOT EXISTS head_voice_type               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_feat_type1               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_feat_type2               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS head_bump_type                SMALLINT,
    ADD COLUMN IF NOT EXISTS head_expression_type          SMALLINT,
    ADD COLUMN IF NOT EXISTS head_eye_type                 SMALLINT,
    ADD COLUMN IF NOT EXISTS head_dark_tail                SMALLINT,
    ADD COLUMN IF NOT EXISTS head_eye_color2               INTEGER,
    ADD COLUMN IF NOT EXISTS head_eye_lash                 SMALLINT,
    -- Weekly abyss
    ADD COLUMN IF NOT EXISTS this_week_compare_time        INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS this_week_abyss_kill_cnt      INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS this_week_abyss_point         BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_week_abyss_kill_cnt      INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_week_abyss_point         BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_abyss_kill_cnt          INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS best_abyss_rank               INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS today_compare_time            INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS today_abyss_kill_cnt          INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS today_abyss_point             BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_freefly                    SMALLINT     NOT NULL DEFAULT 0,
    -- Visual: 39 feat_* face/body shape columns
    ADD COLUMN IF NOT EXISTS feat_version                  SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_face_shape               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_forehead_shape           SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_position             SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_glabella             SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_length               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_height               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_shape                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eye_tail                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eyeblow_pos              SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eyeblow_angle            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_eyeblow_shape            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_nose_pos                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_nose_bridge              SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_nose_side                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_nose_tip                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_cheek_shape              SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_mouth_pos                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_mouth_size               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_lip_thickness            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_lip_tail                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_lip_shape                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_jaw_pos                  SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_jaw_shape                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_ear_shape                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_head_size                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_neck_thickness           SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_neck_length              SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_shoulder_size            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_upper_size               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_bust_size                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_waist_size               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_hip_size                 SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_arm_thickness            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_hand_size                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_leg_thickness            SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_foot_size                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_face_ratio               SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_wing_size                SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS feat_arm_length               SMALLINT     NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS feat_leg_length               SMALLINT     NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS feat_shoulder_width           SMALLINT     NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS feat_head_figure              SMALLINT,
    ADD COLUMN IF NOT EXISTS feat_head_eye_size            SMALLINT,
    ADD COLUMN IF NOT EXISTS feat_upper_height             SMALLINT,
    ADD COLUMN IF NOT EXISTS feat_arm_lower_thickness      SMALLINT,
    ADD COLUMN IF NOT EXISTS feat_hand_length              SMALLINT,
    ADD COLUMN IF NOT EXISTS feat_leg_lower_thickness      SMALLINT,
    -- Misc / pvp / serial / housing
    ADD COLUMN IF NOT EXISTS optionflags                   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS delete_complete_date          INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cashitem_inventory_growth     SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cashitem_warehouse_growth     SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS accused_count                 INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_accuse_time              INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pay_stat                      SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS delete_type                   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bot_point                     INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS vital_point                   BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pvp_exp                       BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serial_kill_point             INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serial_kill_penalty_duration  INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serial_kill_penalty_skill_rank INTEGER     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS enhanced_stigma_slot_cnt      SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS account_punishment            SMALLINT,
    ADD COLUMN IF NOT EXISTS item_legacy                   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS login_server                  INTEGER      DEFAULT 0,
    ADD COLUMN IF NOT EXISTS housing_id                    INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS today_glory_point             INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS this_week_glory_point         INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_week_glory_point         INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fatigue_resttime_online       INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS next_hotspot_use_time         BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_explicit_beginner_force  SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gotcha_fever_point            INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gotcha_fever_expire_time      BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gotcha_fever_hit_count        INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS absolute_exp                  BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serial_guard_point            INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS serial_guard_last_scantime    INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS guild_offline_change_flag     SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_jumping_character          SMALLINT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS two_weeks_ago_glory_point     INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS three_weeks_ago_glory_point   INTEGER      NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS absolute_ap                   BIGINT       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS hardware                      VARCHAR(16);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 2. user_item — add NCSoft fields needed by GetItemList/SetItemEnchant
--    export_id (unsent vs sent for trade), main_item_dbid (godstone link).
-- ====================================================================
ALTER TABLE user_item
    ADD COLUMN IF NOT EXISTS export_id     BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS import_id     BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS main_item_dbid BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS create_date   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS update_date   TIMESTAMPTZ NOT NULL DEFAULT NOW();
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 3. user_item_option — add NCSoft fields for SetItemEnchant_20180615.
--    wardrobeSlotId/randomAttr1..10/randomValue1..10/skill_skin_name_Id/
--    equipLevelDown/proc_break_count/proc_break_flag/stat_enchant_0..5.
-- ====================================================================
-- All identifiers UNQUOTED so PG folds to lower-case, consistent with the
-- way 00008 created the original user_item_option columns (KeyNameId etc.
-- are stored as lowercase in the catalog despite the mixed-case literal).
ALTER TABLE user_item_option
    ADD COLUMN IF NOT EXISTS wardrobeSlotId     SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS equipLevelDown     SMALLINT,
    ADD COLUMN IF NOT EXISTS proc_break_count   INTEGER,
    ADD COLUMN IF NOT EXISTS proc_break_flag    SMALLINT,
    ADD COLUMN IF NOT EXISTS skill_skin_name_id INTEGER NOT NULL DEFAULT 0,
    -- random attribute slot pairs (1..10)
    ADD COLUMN IF NOT EXISTS randomAttr1  INTEGER, ADD COLUMN IF NOT EXISTS randomValue1  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr2  INTEGER, ADD COLUMN IF NOT EXISTS randomValue2  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr3  INTEGER, ADD COLUMN IF NOT EXISTS randomValue3  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr4  INTEGER, ADD COLUMN IF NOT EXISTS randomValue4  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr5  INTEGER, ADD COLUMN IF NOT EXISTS randomValue5  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr6  INTEGER, ADD COLUMN IF NOT EXISTS randomValue6  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr7  INTEGER, ADD COLUMN IF NOT EXISTS randomValue7  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr8  INTEGER, ADD COLUMN IF NOT EXISTS randomValue8  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr9  INTEGER, ADD COLUMN IF NOT EXISTS randomValue9  INTEGER,
    ADD COLUMN IF NOT EXISTS randomAttr10 INTEGER, ADD COLUMN IF NOT EXISTS randomValue10 INTEGER;
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 4. user_skill_cooltime — RESHAPE to NCSoft form.
--    Round 5 used (char_id, skill_id, use_time) — wrong. NCSoft persists
--    the entire cooldown table as one varbinary blob per char; the client
--    decodes it on login. Drop and recreate to match.
-- ====================================================================
DROP TABLE IF EXISTS user_skill_cooltime;
CREATE TABLE user_skill_cooltime (
    char_id            INTEGER  PRIMARY KEY,
    cooltime_data_cnt  SMALLINT NOT NULL DEFAULT 0,
    data               BYTEA    NOT NULL DEFAULT '\x'::BYTEA
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 5. user_skill_skin — RESHAPE. Round 5 used (char_id, skill_id, skill_skin)
--    — wrong. NCSoft uses (char_id, skill_skin_id) PK with use_skin/expire.
-- ====================================================================
DROP TABLE IF EXISTS user_skill_skin;
CREATE TABLE user_skill_skin (
    char_id        INTEGER     NOT NULL,
    skill_skin_id  SMALLINT    NOT NULL,
    expire_time    INTEGER,
    use_skin       SMALLINT    NOT NULL DEFAULT 0,
    update_time    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (char_id, skill_skin_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 6. user_finished_quest — new table. PutFinishedQuestSimple inserts here.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_finished_quest (
    char_id              INTEGER NOT NULL,
    quest_id             INTEGER NOT NULL,
    quest_count          INTEGER NOT NULL DEFAULT 1,
    quest_branch         SMALLINT NOT NULL DEFAULT 0,
    quest_finishedtime   INTEGER          DEFAULT 0,
    repeat_quest_count   INTEGER NOT NULL DEFAULT 1,
    repeat_quest_resetnum INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, quest_id, quest_branch)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_finished_quest_char ON user_finished_quest(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- ====================================================================
-- 7. user_mail — add columns referenced by MailList/MailRead/MailDelete:
--    state (read flag — supersedes is_read), abyss_point, item_count.
-- ====================================================================
ALTER TABLE user_mail
    ADD COLUMN IF NOT EXISTS state         SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS abyss_point   BIGINT   NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose Down

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_finished_quest_char;
DROP TABLE IF EXISTS user_finished_quest;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_skill_skin;
CREATE TABLE user_skill_skin (
    char_id      INTEGER NOT NULL,
    skill_id     INTEGER NOT NULL,
    skill_skin   INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, skill_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_skill_cooltime;
CREATE TABLE user_skill_cooltime (
    char_id     INTEGER NOT NULL,
    skill_id    INTEGER NOT NULL,
    use_time    INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, skill_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_mail
    DROP COLUMN IF EXISTS abyss_point,
    DROP COLUMN IF EXISTS state;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_item_option
    DROP COLUMN IF EXISTS randomValue10, DROP COLUMN IF EXISTS randomAttr10,
    DROP COLUMN IF EXISTS randomValue9,  DROP COLUMN IF EXISTS randomAttr9,
    DROP COLUMN IF EXISTS randomValue8,  DROP COLUMN IF EXISTS randomAttr8,
    DROP COLUMN IF EXISTS randomValue7,  DROP COLUMN IF EXISTS randomAttr7,
    DROP COLUMN IF EXISTS randomValue6,  DROP COLUMN IF EXISTS randomAttr6,
    DROP COLUMN IF EXISTS randomValue5,  DROP COLUMN IF EXISTS randomAttr5,
    DROP COLUMN IF EXISTS randomValue4,  DROP COLUMN IF EXISTS randomAttr4,
    DROP COLUMN IF EXISTS randomValue3,  DROP COLUMN IF EXISTS randomAttr3,
    DROP COLUMN IF EXISTS randomValue2,  DROP COLUMN IF EXISTS randomAttr2,
    DROP COLUMN IF EXISTS randomValue1,  DROP COLUMN IF EXISTS randomAttr1,
    DROP COLUMN IF EXISTS skill_skin_name_id,
    DROP COLUMN IF EXISTS proc_break_flag,
    DROP COLUMN IF EXISTS proc_break_count,
    DROP COLUMN IF EXISTS equipLevelDown,
    DROP COLUMN IF EXISTS wardrobeSlotId;
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_item
    DROP COLUMN IF EXISTS update_date,
    DROP COLUMN IF EXISTS create_date,
    DROP COLUMN IF EXISTS main_item_dbid,
    DROP COLUMN IF EXISTS import_id,
    DROP COLUMN IF EXISTS export_id;
-- +goose StatementEnd

-- +goose StatementBegin
-- Reverting all 99+ user_data columns is intentionally not done — the down
-- direction targets the structural changes only. Production never uses Down.
-- +goose StatementEnd
