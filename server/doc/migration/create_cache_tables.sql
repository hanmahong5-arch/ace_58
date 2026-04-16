CREATE TABLE IF NOT EXISTS account_data (
  account_id INTEGER,
  hidden_fatigue_point INTEGER,
  hidden_fatigue_updatetime INTEGER,
  hidden_fatigue_npckill INTEGER,
  limit_play_reset_time INTEGER,
  limit_play_accum_time INTEGER
);

CREATE TABLE IF NOT EXISTS account_fatigue (
  account_id INTEGER,
  sun INTEGER,
  mon INTEGER,
  tue INTEGER,
  wed CHAR(10),
  thu CHAR(10),
  fri CHAR(10),
  sat CHAR(10),
  sun_pccafe CHAR(10),
  mon_pccafe CHAR(10),
  tue_pccafe CHAR(10),
  wed_pccafe CHAR(10),
  thu_pccafe CHAR(10),
  fri_pccafe CHAR(10),
  sat_pccafe CHAR(10)
);

CREATE TABLE IF NOT EXISTS account_luna (
  accountid INTEGER,
  luna BIGINT,
  createdate TIMESTAMP,
  updatedate TIMESTAMP
);

CREATE TABLE IF NOT EXISTS account_luna_reward (
  accountid INTEGER,
  today_reward INTEGER,
  remain_reward INTEGER,
  key_count INTEGER,
  createdate TIMESTAMP,
  updatedate TIMESTAMP
);

CREATE TABLE IF NOT EXISTS account_pack (
  account_id INTEGER,
  pack_type SMALLINT,
  expire_date INTEGER,
  id BIGINT
);

CREATE TABLE IF NOT EXISTS account_playtime_polls (
  account_id INTEGER,
  poll_id INTEGER,
  previous_playtime BIGINT
);

CREATE TABLE IF NOT EXISTS aion_ranking_info (
  id BIGINT,
  specialservertype INTEGER,
  rankid INTEGER,
  seasonnumber INTEGER,
  lastupdatetime TIMESTAMP,
  seasonstatus INTEGER,
  tabledump TEXT,
  tableversion INTEGER
);

CREATE TABLE IF NOT EXISTS aion_ranking_season_status (
  specialservertype INTEGER,
  rankid INTEGER,
  seasonnumber INTEGER,
  seasonstatus INTEGER,
  seasonstarttime TIMESTAMP,
  lastupdatetime TIMESTAMP
);

CREATE TABLE IF NOT EXISTS aion_server_data (
  server_id INTEGER,
  movesvr_last_checktime INTEGER
);

CREATE TABLE IF NOT EXISTS aion_serverlist (
  server_id INTEGER,
  datasource VARCHAR(128),
  database_name VARCHAR(64),
  update_result INTEGER
);

CREATE TABLE IF NOT EXISTS aion_user_ranking_season_history (
  serverid INTEGER,
  rankid INTEGER,
  seasonnumber INTEGER,
  characterid INTEGER,
  rankpoint INTEGER,
  ranking INTEGER,
  rewarded INTEGER,
  charactername VARCHAR(100),
  iccharacterid INTEGER,
  accountid INTEGER,
  accountname VARCHAR(100),
  rewardeddate TIMESTAMP
);

CREATE TABLE IF NOT EXISTS aion_user_ranking_servermove (
  id BIGINT,
  srcserverid INTEGER,
  srccharacterid INTEGER,
  dstserverid INTEGER,
  dstcharacterid INTEGER,
  charactername VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS cosmetic_data (
  cosmetic_id INTEGER,
  account_id INTEGER,
  server_id SMALLINT,
  char_id INTEGER,
  race SMALLINT,
  gender SMALLINT,
  feat_version SMALLINT,
  head_face_color INTEGER,
  head_hair_color INTEGER,
  head_eye_color INTEGER,
  head_lip_color INTEGER,
  head_face_type SMALLINT,
  head_hair_type SMALLINT,
  height_scale DOUBLE PRECISION,
  head_voice_type SMALLINT,
  head_feat_type1 SMALLINT,
  head_feat_type2 SMALLINT,
  head_bump_type SMALLINT,
  head_expression_type SMALLINT,
  feat_face_shape SMALLINT,
  feat_forehead_shape SMALLINT,
  feat_eye_position SMALLINT,
  feat_eye_glabella SMALLINT,
  feat_eye_length SMALLINT,
  feat_eye_height SMALLINT,
  feat_eye_shape SMALLINT,
  feat_eye_tail SMALLINT,
  feat_eyeblow_pos SMALLINT,
  feat_eyeblow_angle SMALLINT,
  feat_eyeblow_shape SMALLINT,
  feat_nose_pos SMALLINT,
  feat_nose_bridge SMALLINT,
  feat_nose_side SMALLINT,
  feat_nose_tip SMALLINT,
  feat_cheek_shape SMALLINT,
  feat_mouth_pos SMALLINT,
  feat_mouth_size SMALLINT,
  feat_lip_thickness SMALLINT,
  feat_lip_tail SMALLINT,
  feat_lip_shape SMALLINT,
  feat_jaw_pos SMALLINT,
  feat_jaw_shape SMALLINT,
  feat_head_size SMALLINT,
  feat_neck_thickness SMALLINT,
  feat_neck_length SMALLINT,
  feat_shoulder_size SMALLINT,
  feat_upper_size SMALLINT,
  feat_bust_size SMALLINT,
  feat_waist_size SMALLINT,
  feat_hip_size SMALLINT,
  feat_arm_thickness SMALLINT,
  feat_hand_size SMALLINT,
  feat_leg_thickness SMALLINT,
  feat_foot_size SMALLINT,
  feat_wing_size SMALLINT,
  feat_ear_shape SMALLINT,
  feat_face_ratio SMALLINT,
  feat_arm_length SMALLINT,
  feat_leg_length SMALLINT,
  feat_shoulder_width SMALLINT,
  feat_head_figure SMALLINT,
  create_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS global_user_data (
  char_id INTEGER,
  account_id INTEGER,
  create_date TIMESTAMP,
  last_login_time TIMESTAMP,
  last_logout_time TIMESTAMP,
  delete_date INTEGER,
  delete_completed_date INTEGER,
  user_level INTEGER,
  server_id INTEGER,
  cur_server_id INTEGER,
  global_char_id BIGINT,
  uid INTEGER,
  class_type INTEGER,
  race_type INTEGER,
  is_special_server SMALLINT,
  is_jumping_character SMALLINT
);

CREATE TABLE IF NOT EXISTS jumping_character_config (
  server_id INTEGER,
  is_special_server SMALLINT,
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  max_creation_count INTEGER,
  required_char_level INTEGER,
  is_deleted SMALLINT,
  login_id VARCHAR(30),
  login_nm VARCHAR(30),
  reg_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS server_operation (
  id INTEGER,
  operation SMALLINT,
  orgserverid INTEGER,
  newserverid INTEGER
);

CREATE TABLE IF NOT EXISTS test_data (
  id INTEGER,
  int_value INTEGER,
  nchar10_value CHAR(10),
  date_value TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trial_account_data (
  account_id INTEGER,
  update_time INTEGER,
  reset_time INTEGER,
  sell_gold_sum BIGINT,
  trade_gold_sum BIGINT,
  decompose_sum INTEGER,
  gather_sum INTEGER,
  extract_gather_sum INTEGER,
  id BIGINT
);

CREATE TABLE IF NOT EXISTS user_board_bm (
  account_id INTEGER,
  game_id INTEGER,
  current_pos INTEGER,
  visited_pos BIGINT,
  last_freecharge_time BIGINT,
  last_reset_time BIGINT,
  free_dice_remain INTEGER,
  paid_dice_remain INTEGER,
  paid_reset_remain INTEGER
);

CREATE TABLE IF NOT EXISTS user_board_bm_dice (
  account_id INTEGER,
  last_freecharge_time BIGINT,
  free_dice_remain INTEGER,
  paid_dice_remain INTEGER,
  paid_reset_remain INTEGER
);

CREATE TABLE IF NOT EXISTS user_board_bm_game (
  account_id INTEGER,
  is_special_server SMALLINT,
  game_id INTEGER,
  current_pos INTEGER,
  visited_pos BIGINT,
  last_reset_time BIGINT
);

CREATE TABLE IF NOT EXISTS user_login_event_data (
  id BIGINT,
  account_id INTEGER,
  event_id INTEGER,
  stamp_count INTEGER,
  recent_count_update_date TIMESTAMP,
  recent_anniversity_reward_time BIGINT
);

CREATE TABLE IF NOT EXISTS user_login_event_data_daily (
  id BIGINT,
  account_id INTEGER,
  event_id INTEGER,
  valid_login_count INTEGER,
  recent_count_update_date TIMESTAMP,
  be_rewarded INTEGER
);

CREATE TABLE IF NOT EXISTS user_login_event_data_other (
  id BIGINT,
  account_id INTEGER,
  event_id INTEGER,
  valid_login_count INTEGER,
  recent_count_update_date TIMESTAMP,
  be_rewarded INTEGER
);

CREATE TABLE IF NOT EXISTS user_login_event_data_renewal (
  id BIGINT,
  accountid INTEGER,
  specialsvrtype INTEGER,
  eventid INTEGER,
  stampcount INTEGER,
  recentcountupdatedate TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_monster_core (
  id INTEGER,
  account_id INTEGER,
  core_id INTEGER,
  core_grade INTEGER,
  core_count INTEGER,
  total_added INTEGER,
  total_used INTEGER
);

CREATE TABLE IF NOT EXISTS user_promotion_cooltime (
  account_id INTEGER,
  promotion_id INTEGER,
  last_promotion_time INTEGER,
  received_item_count INTEGER,
  cycle_received_item_count INTEGER,
  cycle_next_reset_time INTEGER
);

CREATE TABLE IF NOT EXISTS user_transform (
  account_id INTEGER,
  name_id INTEGER,
  count INTEGER,
  update_time TIMESTAMP,
  server_id INTEGER
);