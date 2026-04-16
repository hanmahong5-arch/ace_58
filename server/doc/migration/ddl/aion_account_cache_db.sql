-- PostgreSQL DDL for database: aion_account_cache_db
-- Generated from SQL Server schema: AionAccountCacheDB
-- Tables: 28

CREATE TABLE account_data (
    account_id integer NOT NULL,
    hidden_fatigue_point integer DEFAULT 0 NOT NULL,
    hidden_fatigue_updatetime integer DEFAULT 0 NOT NULL,
    hidden_fatigue_npckill integer DEFAULT 0 NULL,
    limit_play_reset_time integer DEFAULT 0 NOT NULL,
    limit_play_accum_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_account_data PRIMARY KEY (account_id)
);

CREATE TABLE account_fatigue (
    account_id integer NOT NULL,
    sun integer NULL,
    mon integer NULL,
    tue integer NULL,
    wed char(10) NULL,
    thu char(10) NULL,
    fri char(10) NULL,
    sat char(10) NULL,
    sun_pccafe char(10) NULL,
    mon_pccafe char(10) NULL,
    tue_pccafe char(10) NULL,
    wed_pccafe char(10) NULL,
    thu_pccafe char(10) NULL,
    fri_pccafe char(10) NULL,
    sat_pccafe char(10) NULL,
    CONSTRAINT pk_account_fatigue PRIMARY KEY (account_id)
);

CREATE TABLE account_luna (
    accountid integer NOT NULL,
    luna bigint DEFAULT 0 NOT NULL,
    createdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updatedate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_account_luna PRIMARY KEY (accountid)
);

CREATE TABLE account_luna_reward (
    accountid integer NOT NULL,
    today_reward integer DEFAULT 0 NOT NULL,
    remain_reward integer DEFAULT 0 NOT NULL,
    key_count integer DEFAULT 0 NOT NULL,
    createdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updatedate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_account_luna_reward PRIMARY KEY (accountid)
);

CREATE TABLE account_pack (
    account_id integer NOT NULL,
    pack_type smallint NOT NULL,
    expire_date integer NOT NULL,
    id bigint NOT NULL,
    CONSTRAINT pk_account_pack PRIMARY KEY (id)
);

CREATE TABLE account_playtime_polls (
    account_id integer NOT NULL,
    poll_id integer NOT NULL,
    previous_playtime bigint NOT NULL,
    CONSTRAINT pk_account_playtime_polls PRIMARY KEY (account_id, poll_id)
);

CREATE TABLE aion_ranking_info (
    id bigint NOT NULL,
    specialservertype integer NOT NULL,
    rankid integer NOT NULL,
    seasonnumber integer NOT NULL,
    lastupdatetime timestamp NOT NULL,
    seasonstatus integer NOT NULL,
    tabledump text NOT NULL,
    tableversion integer NOT NULL,
    CONSTRAINT pk_aion_ranking_info PRIMARY KEY (id)
);

CREATE TABLE aion_ranking_season_status (
    specialservertype integer NOT NULL,
    rankid integer NOT NULL,
    seasonnumber integer NOT NULL,
    seasonstatus integer NOT NULL,
    seasonstarttime timestamp NOT NULL,
    lastupdatetime timestamp NOT NULL,
    CONSTRAINT pk_aion_ranking_season_status PRIMARY KEY (specialservertype, rankid, seasonnumber)
);

CREATE TABLE aion_server_data (
    server_id integer NOT NULL,
    movesvr_last_checktime integer NOT NULL
);

CREATE TABLE aion_serverlist (
    server_id integer NOT NULL,
    datasource varchar(128) NOT NULL,
    database_name varchar(64) NOT NULL,
    update_result integer NULL
);

CREATE TABLE aion_user_ranking_season_history (
    serverid integer NOT NULL,
    rankid integer NOT NULL,
    seasonnumber integer NOT NULL,
    characterid integer NOT NULL,
    rankpoint integer NOT NULL,
    ranking integer NOT NULL,
    rewarded integer NOT NULL,
    charactername varchar(100) NOT NULL,
    iccharacterid integer NOT NULL,
    accountid integer NOT NULL,
    accountname varchar(100) NOT NULL,
    rewardeddate timestamp NULL,
    CONSTRAINT pk_aion_user_ranking_season_history PRIMARY KEY (serverid, rankid, seasonnumber, characterid)
);

CREATE TABLE aion_user_ranking_servermove (
    id bigint NOT NULL,
    srcserverid integer NOT NULL,
    srccharacterid integer NOT NULL,
    dstserverid integer NOT NULL,
    dstcharacterid integer NOT NULL,
    charactername varchar(100) NOT NULL,
    CONSTRAINT pk_aion_user_ranking_servermove PRIMARY KEY (id)
);

CREATE TABLE cosmetic_data (
    cosmetic_id integer NOT NULL,
    account_id integer NOT NULL,
    server_id smallint NOT NULL,
    char_id integer NOT NULL,
    race smallint NOT NULL,
    gender smallint NOT NULL,
    feat_version smallint DEFAULT 0 NOT NULL,
    head_face_color integer NOT NULL,
    head_hair_color integer NOT NULL,
    head_eye_color integer DEFAULT 0xFFFFFFFF NOT NULL,
    head_lip_color integer DEFAULT 0 NOT NULL,
    head_face_type smallint NOT NULL,
    head_hair_type smallint NOT NULL,
    height_scale double precision DEFAULT 1.0 NOT NULL,
    head_voice_type smallint DEFAULT 0 NOT NULL,
    head_feat_type1 smallint DEFAULT 0 NOT NULL,
    head_feat_type2 smallint DEFAULT 0 NOT NULL,
    head_bump_type smallint NOT NULL,
    head_expression_type smallint NOT NULL,
    feat_face_shape smallint DEFAULT 0 NOT NULL,
    feat_forehead_shape smallint DEFAULT 0 NOT NULL,
    feat_eye_position smallint DEFAULT 0 NOT NULL,
    feat_eye_glabella smallint DEFAULT 0 NOT NULL,
    feat_eye_length smallint DEFAULT 0 NOT NULL,
    feat_eye_height smallint DEFAULT 0 NOT NULL,
    feat_eye_shape smallint DEFAULT 0 NOT NULL,
    feat_eye_tail smallint DEFAULT 0 NOT NULL,
    feat_eyeblow_pos smallint DEFAULT 0 NOT NULL,
    feat_eyeblow_angle smallint DEFAULT 0 NOT NULL,
    feat_eyeblow_shape smallint DEFAULT 0 NOT NULL,
    feat_nose_pos smallint DEFAULT 0 NOT NULL,
    feat_nose_bridge smallint DEFAULT 0 NOT NULL,
    feat_nose_side smallint DEFAULT 0 NOT NULL,
    feat_nose_tip smallint DEFAULT 0 NOT NULL,
    feat_cheek_shape smallint DEFAULT 0 NOT NULL,
    feat_mouth_pos smallint DEFAULT 0 NOT NULL,
    feat_mouth_size smallint DEFAULT 0 NOT NULL,
    feat_lip_thickness smallint DEFAULT 0 NOT NULL,
    feat_lip_tail smallint DEFAULT 0 NOT NULL,
    feat_lip_shape smallint DEFAULT 0 NOT NULL,
    feat_jaw_pos smallint DEFAULT 0 NOT NULL,
    feat_jaw_shape smallint DEFAULT 0 NOT NULL,
    feat_head_size smallint DEFAULT 0 NOT NULL,
    feat_neck_thickness smallint DEFAULT 0 NOT NULL,
    feat_neck_length smallint DEFAULT 0 NOT NULL,
    feat_shoulder_size smallint DEFAULT 0 NOT NULL,
    feat_upper_size smallint DEFAULT 0 NOT NULL,
    feat_bust_size smallint DEFAULT 0 NOT NULL,
    feat_waist_size smallint DEFAULT 0 NOT NULL,
    feat_hip_size smallint DEFAULT 0 NOT NULL,
    feat_arm_thickness smallint DEFAULT 0 NOT NULL,
    feat_hand_size smallint DEFAULT 0 NOT NULL,
    feat_leg_thickness smallint DEFAULT 0 NOT NULL,
    feat_foot_size smallint DEFAULT 0 NOT NULL,
    feat_wing_size smallint DEFAULT 0 NOT NULL,
    feat_ear_shape smallint DEFAULT 0 NOT NULL,
    feat_face_ratio smallint DEFAULT 0 NOT NULL,
    feat_arm_length smallint DEFAULT 1 NOT NULL,
    feat_leg_length smallint DEFAULT 1 NOT NULL,
    feat_shoulder_width smallint DEFAULT 1 NOT NULL,
    feat_head_figure smallint NOT NULL,
    create_date timestamp NOT NULL,
    CONSTRAINT pk_cosmetic_data PRIMARY KEY (cosmetic_id)
);

CREATE TABLE global_user_data (
    char_id integer NOT NULL,
    account_id integer NOT NULL,
    create_date timestamp DEFAULT '1753-01-01 00:00:00' NOT NULL,
    last_login_time timestamp DEFAULT '1970-1-1 0:0:1'::timestamp NOT NULL,
    last_logout_time timestamp DEFAULT '1970-1-1 0:0:1'::timestamp NOT NULL,
    delete_date integer DEFAULT 0 NOT NULL,
    delete_completed_date integer DEFAULT 0 NOT NULL,
    user_level integer NOT NULL,
    server_id integer NOT NULL,
    cur_server_id integer DEFAULT 0 NOT NULL,
    global_char_id bigint DEFAULT 0 NOT NULL,
    uid integer NOT NULL,
    class_type integer DEFAULT -1 NOT NULL,
    race_type integer DEFAULT -1 NOT NULL,
    is_special_server smallint DEFAULT 0 NOT NULL,
    is_jumping_character smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_global_user_data PRIMARY KEY (uid)
);

CREATE TABLE jumping_character_config (
    server_id integer NOT NULL,
    is_special_server smallint NOT NULL,
    start_date timestamp NOT NULL,
    end_date timestamp NOT NULL,
    max_creation_count integer NOT NULL,
    required_char_level integer NOT NULL,
    is_deleted smallint NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    reg_date timestamp NOT NULL,
    CONSTRAINT pk_jumping_character_config PRIMARY KEY (server_id)
);

CREATE TABLE server_operation (
    id integer NOT NULL,
    operation smallint DEFAULT 0 NOT NULL,
    orgserverid integer NOT NULL,
    newserverid integer NOT NULL,
    CONSTRAINT pk_server_operation PRIMARY KEY (id)
);

CREATE TABLE test_data (
    id integer NOT NULL,
    int_value integer NOT NULL,
    nchar10_value char(10) NOT NULL,
    date_value timestamp NOT NULL,
    CONSTRAINT pk_test_data PRIMARY KEY (id)
);

CREATE TABLE trial_account_data (
    account_id integer NOT NULL,
    update_time integer DEFAULT 0 NOT NULL,
    reset_time integer DEFAULT 0 NOT NULL,
    sell_gold_sum bigint DEFAULT 0 NOT NULL,
    trade_gold_sum bigint DEFAULT 0 NOT NULL,
    decompose_sum integer DEFAULT 0 NOT NULL,
    gather_sum integer DEFAULT 0 NOT NULL,
    extract_gather_sum integer DEFAULT 0 NOT NULL,
    id bigint NOT NULL,
    CONSTRAINT pk_trial_account_data PRIMARY KEY (id)
);

CREATE TABLE user_board_bm (
    account_id integer NOT NULL,
    game_id integer NOT NULL,
    current_pos integer NOT NULL,
    visited_pos bigint NOT NULL,
    last_freecharge_time bigint NOT NULL,
    last_reset_time bigint NOT NULL,
    free_dice_remain integer NOT NULL,
    paid_dice_remain integer NOT NULL,
    paid_reset_remain integer NOT NULL,
    CONSTRAINT pk_user_board_bm PRIMARY KEY (account_id)
);

CREATE TABLE user_board_bm_dice (
    account_id integer NOT NULL,
    last_freecharge_time bigint NOT NULL,
    free_dice_remain integer NOT NULL,
    paid_dice_remain integer NOT NULL,
    paid_reset_remain integer NOT NULL,
    CONSTRAINT pk_user_board_bm_dice PRIMARY KEY (account_id)
);

CREATE TABLE user_board_bm_game (
    account_id integer NOT NULL,
    is_special_server smallint NOT NULL,
    game_id integer NOT NULL,
    current_pos integer NOT NULL,
    visited_pos bigint NOT NULL,
    last_reset_time bigint NOT NULL,
    CONSTRAINT pk_user_board_bm_game PRIMARY KEY (account_id, is_special_server)
);

CREATE TABLE user_login_event_data (
    id bigint NOT NULL,
    account_id integer NOT NULL,
    event_id integer NOT NULL,
    stamp_count integer NOT NULL,
    recent_count_update_date timestamp NOT NULL,
    recent_anniversity_reward_time bigint NOT NULL,
    CONSTRAINT pk_user_login_event_data PRIMARY KEY (id)
);

CREATE TABLE user_login_event_data_daily (
    id bigint NOT NULL,
    account_id integer NOT NULL,
    event_id integer NOT NULL,
    valid_login_count integer NOT NULL,
    recent_count_update_date timestamp NOT NULL,
    be_rewarded integer NOT NULL,
    CONSTRAINT pk_user_login_event_data_daily PRIMARY KEY (id)
);

CREATE TABLE user_login_event_data_other (
    id bigint NOT NULL,
    account_id integer NOT NULL,
    event_id integer NOT NULL,
    valid_login_count integer NOT NULL,
    recent_count_update_date timestamp NOT NULL,
    be_rewarded integer NOT NULL,
    CONSTRAINT pk_user_login_event_data_other PRIMARY KEY (id)
);

CREATE TABLE user_login_event_data_renewal (
    id bigint NOT NULL,
    accountid integer NOT NULL,
    specialsvrtype integer NOT NULL,
    eventid integer NOT NULL,
    stampcount integer NOT NULL,
    recentcountupdatedate timestamp NOT NULL,
    CONSTRAINT pk_user_login_event_data_renewal PRIMARY KEY (id)
);

CREATE TABLE user_monster_core (
    id integer NOT NULL,
    account_id integer NULL,
    core_id integer NULL,
    core_grade integer NULL,
    core_count integer NULL,
    total_added integer NULL,
    total_used integer NULL,
    CONSTRAINT pk_user_monster_core PRIMARY KEY (id)
);

CREATE TABLE user_promotion_cooltime (
    account_id integer NOT NULL,
    promotion_id integer NOT NULL,
    last_promotion_time integer NOT NULL,
    received_item_count integer NOT NULL,
    cycle_received_item_count integer NOT NULL,
    cycle_next_reset_time integer NOT NULL,
    CONSTRAINT pk_user_promotion_cooltime PRIMARY KEY (account_id, promotion_id)
);

CREATE TABLE user_transform (
    account_id integer NOT NULL,
    name_id integer NOT NULL,
    count integer NOT NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    server_id integer NULL,
    CONSTRAINT pk_user_transform PRIMARY KEY (account_id, name_id)
);

-- ── Indexes ──────────────────────────────────────────

CREATE UNIQUE INDEX uk_account_pack ON account_pack (account_id, pack_type);
CREATE INDEX ix_aion_ranking_info_specialservertype_rankid_seasonnumber_lastupdatetime ON aion_ranking_info (specialservertype, rankid, seasonnumber, lastupdatetime);
CREATE INDEX ix_aion_user_ranking_season_history_serverid_rewarded ON aion_user_ranking_season_history (serverid, rewarded);
CREATE INDEX ix_global_user_data ON global_user_data (char_id, server_id);
CREATE INDEX ix_global_user_data_accountid ON global_user_data (account_id);
CREATE INDEX ix_global_user_data_server_id ON global_user_data (server_id);
CREATE INDEX ix_server_operation ON server_operation (operation);
CREATE UNIQUE INDEX uk_trial_account_data ON trial_account_data (account_id);
CREATE UNIQUE INDEX ix_user_login_event_data ON user_login_event_data (account_id);
CREATE INDEX ix_user_login_event_data_daily ON user_login_event_data_daily (account_id, event_id);
CREATE UNIQUE INDEX ix_user_login_event_data_other ON user_login_event_data_other (account_id, event_id);
CREATE INDEX ix_user_login_event_data_renewal_accountid ON user_login_event_data_renewal (accountid, specialsvrtype);
CREATE UNIQUE INDEX ux_user_login_event_data_renewal_accountid_eventid_specialsvrtype ON user_login_event_data_renewal (accountid, eventid, specialsvrtype);
CREATE INDEX ix_account_id_core_id ON user_monster_core (account_id, core_id);
