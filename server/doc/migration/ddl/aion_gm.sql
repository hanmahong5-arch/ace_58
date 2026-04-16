-- PostgreSQL DDL for database: aion_gm
-- Generated from SQL Server schema: LIVE_AionGM
-- Tables: 63

CREATE TABLE tbl_admin_group (
    group_id varchar(20) NOT NULL,
    group_nm varchar(50) NOT NULL,
    is_deleted char(1) NOT NULL,
    CONSTRAINT pk_tbl_admin_group PRIMARY KEY (group_id)
);

CREATE TABLE tbl_admin_log_202009 (
    admin_logid integer NOT NULL,
    login_id varchar(30) NOT NULL,
    admin_ip varchar(15) NOT NULL,
    menu_id integer NOT NULL,
    action_code varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    log_info varchar(3000) NOT NULL
);

CREATE TABLE tbl_admin_menu (
    menu_id integer NOT NULL,
    menu_group_code varchar(200) NOT NULL,
    menu_code varchar(50) NOT NULL,
    menu_depth integer NOT NULL,
    menu_url varchar(300) NOT NULL,
    menu_target varchar(30) NOT NULL,
    menu_img varchar(100) NOT NULL,
    is_menu char(1) NOT NULL,
    CONSTRAINT pk_tbl_admin_menu PRIMARY KEY (menu_id)
);

CREATE TABLE tbl_admin_options (
    option_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    option_code varchar(50) NOT NULL,
    option_name varchar(50) NOT NULL,
    option_type varchar(10) NULL
);

CREATE TABLE tbl_admin_organization (
    organization_id integer NOT NULL,
    organization_nm varchar(70) NOT NULL,
    organization_info varchar(200) NULL,
    CONSTRAINT pk_tbl_admin_organization PRIMARY KEY (organization_id)
);

CREATE TABLE tbl_admin_user (
    admin_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    login_pw varchar(32) NOT NULL,
    login_nm varchar(30) NOT NULL,
    login_email varchar(70) NOT NULL,
    organization_id integer NOT NULL,
    is_deleted char(1) NOT NULL,
    etc varchar(700) NOT NULL,
    regdate timestamp NOT NULL,
    pwdate timestamp NULL,
    admin_level smallint NULL,
    auth_update_date timestamp NOT NULL,
    password_wrong_cnt smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_tbl_admin_user PRIMARY KEY (admin_id)
);

CREATE TABLE tbl_admin_user_history (
    admin_id integer NOT NULL,
    by_admin_id integer NOT NULL,
    history_cd varchar(30) NOT NULL,
    history_info varchar(300) NOT NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_admin_user_pw_history (
    id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    login_pw varchar(32) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_admin_user_pw_history PRIMARY KEY (id)
);

CREATE TABLE tbl_alert_event (
    alert_event_id integer NOT NULL,
    world_id integer NOT NULL,
    event_id integer NOT NULL,
    event_cate varchar(10) NOT NULL,
    grp_cd varchar(2) NOT NULL,
    priority smallint NOT NULL,
    is_popup char(1) NOT NULL,
    event_info varchar(500) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_alert_event PRIMARY KEY (alert_event_id)
);

CREATE TABLE tbl_approval_animation (
    approval_animation_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    animation_id smallint NOT NULL,
    animation_type smallint NOT NULL,
    expire_time integer NOT NULL,
    approval_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_approval_animation PRIMARY KEY (approval_animation_id)
);

CREATE TABLE tbl_approval_char (
    approval_char_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    char_nm varchar(50) NULL,
    char_gender smallint NULL,
    char_race smallint NULL,
    char_class smallint NULL,
    char_lev smallint NULL,
    char_exp varchar(50) NULL,
    char_sp varchar(5) NULL,
    char_pk varchar(5) NULL,
    char_hair smallint NULL,
    char_face smallint NULL,
    char_feat1 smallint NULL,
    char_feat2 smallint NULL,
    char_hair_color integer NULL,
    char_eye_color integer NULL,
    char_skin_color integer NULL,
    char_voice smallint NULL,
    char_height_scale double precision NULL,
    char_stigma_point varchar(10) NULL,
    char_abyss_point varchar(30) NULL,
    char_type char(1) NOT NULL,
    char_delete smallint NOT NULL,
    inven_cube_kina_lv smallint NULL,
    inven_cube_quest_lv smallint NULL,
    ware_cube_kina_lv smallint NULL,
    ware_cube_quest_lv smallint NULL,
    bot_point varchar(30) NULL,
    lost_exp varchar(50) NULL,
    stigma_slot smallint DEFAULT 0 NULL,
    death_count varchar(3) NULL,
    today_abyss_kill_cnt varchar(6) NULL,
    today_abyss_point varchar(30) NULL,
    this_week_abyss_kill_cnt varchar(6) NULL,
    this_week_abyss_point varchar(30) NULL,
    last_week_abyss_kill_cnt varchar(6) NULL,
    last_week_abyss_point varchar(30) NULL,
    total_abyss_kill_cnt varchar(6) NULL,
    best_abyss_rank varchar(30) NULL,
    glory_point varchar(10) NULL,
    today_glory_point varchar(10) NULL,
    this_week_glory_point varchar(10) NULL,
    last_week_glory_point varchar(10) NULL
);

CREATE TABLE tbl_approval_default_stage (
    approval_default_stage_id integer NOT NULL,
    approval_stage_num integer NOT NULL,
    workflow_cd varchar(30) NOT NULL,
    login_id varchar(30) NOT NULL,
    is_final char(1) NOT NULL,
    organization_id integer NOT NULL,
    approval_group varchar(20) NOT NULL,
    CONSTRAINT pk_tbl_approval_default_stage PRIMARY KEY (approval_default_stage_id)
);

CREATE TABLE tbl_approval_guild (
    approval_guild_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    guild_id integer NULL,
    guild_nm varchar(32) NULL,
    guild_lv smallint NULL,
    guild_point integer NULL,
    guild_etc1 varchar(50) NULL,
    guild_etc2 varchar(50) NULL,
    guild_etc3 varchar(50) NULL,
    char_type char(1) NOT NULL,
    approval_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_approval_guild PRIMARY KEY (approval_guild_id)
);

CREATE TABLE tbl_approval_history (
    approval_history_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    login_id varchar(30) NOT NULL,
    approval_status varchar(30) NOT NULL,
    approval_stage_num integer NOT NULL,
    approval_history_info varchar(200) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_approval_history PRIMARY KEY (approval_history_id)
);

CREATE TABLE tbl_approval_info (
    approval_info_id varchar(30) NOT NULL,
    approval_type varchar(30) NOT NULL,
    communication_cd varchar(30) NOT NULL,
    world_id integer NOT NULL,
    approval_char_id varchar(15) NOT NULL,
    approval_char_nm varchar(30) NOT NULL,
    approval_account_id varchar(15) NOT NULL,
    approval_account_nm varchar(30) NOT NULL,
    approval_info varchar(400) NULL,
    approval_recovery_info varchar(1000) NULL,
    approval_petition_info text NULL,
    approval_log_info text NULL,
    login_id varchar(30) NOT NULL,
    approval_status varchar(30) NOT NULL,
    approval_stage_num integer NOT NULL,
    approval_group varchar(20) NOT NULL,
    workflow_cd varchar(30) NOT NULL,
    approval_checkinout_id varchar(30) NULL,
    approval_checkinout_nm varchar(30) NULL,
    approval_checkinout_status char(1) NOT NULL,
    approval_checkinout_regdate timestamp NULL,
    regdate timestamp NOT NULL,
    is_mail char(1) NULL,
    is_paid varchar(20) NULL,
    doc_type varchar(3) NULL,
    CONSTRAINT pk_tbl_approval_info PRIMARY KEY (approval_info_id)
);

CREATE TABLE tbl_approval_item (
    approval_item_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    item_id varchar(30) NOT NULL,
    db_item_id varchar(30) NULL,
    item_cnt bigint NOT NULL,
    item_pkg_cnt integer NULL,
    item_enchant smallint NULL,
    slot_id smallint NULL,
    slot smallint NULL,
    soul_bound smallint NULL,
    skin_name_id integer NULL,
    stat_enchant_type0 smallint NULL,
    stat_enchant_val0 smallint NULL,
    stat_enchant_type1 smallint NULL,
    stat_enchant_val1 smallint NULL,
    stat_enchant_type2 smallint NULL,
    stat_enchant_val2 smallint NULL,
    stat_enchant_type3 smallint NULL,
    stat_enchant_val3 smallint NULL,
    stat_enchant_type4 smallint NULL,
    stat_enchant_val4 smallint NULL,
    stat_enchant_type5 smallint NULL,
    stat_enchant_val5 smallint NULL,
    option_count smallint NULL,
    dye_info integer NULL,
    proc_tool_nameid integer NULL,
    producer varchar(20) NULL,
    item_deposit smallint NULL,
    is_stackable integer NULL,
    target_world_id integer NULL,
    target_char_id varchar(15) NULL,
    target_char_nm varchar(30) NULL,
    target_account_id varchar(15) NULL,
    target_account_nm varchar(30) NULL,
    approval_type varchar(30) NOT NULL,
    expired_time integer NULL,
    compound_type smallint NULL,
    charge_point integer NULL,
    seal_state smallint NULL,
    seal_expired_time integer NULL,
    expire_skin_time integer NULL,
    expire_dye_time integer NULL,
    random_option smallint NULL,
    stat_enchant_name0 integer NULL,
    stat_enchant_name1 integer NULL,
    stat_enchant_name2 integer NULL,
    stat_enchant_name3 integer NULL,
    stat_enchant_name4 integer NULL,
    stat_enchant_name5 integer NULL,
    limit_enchant_count smallint NULL,
    reidentify_count smallint NULL,
    polish_name_id integer NULL,
    random_id integer NULL,
    polish_point integer NULL,
    freetradestate integer NULL,
    authorize_count smallint NULL,
    vanish_point integer NULL,
    attribute1 integer NULL,
    attribute1value integer NULL,
    attribute2 integer NULL,
    attribute2value integer NULL,
    attribute3 integer NULL,
    attribute3value integer NULL,
    attribute4 integer NULL,
    attribute4value integer NULL,
    attribute5 integer NULL,
    attribute5value integer NULL,
    attribute6 integer NULL,
    attribute6value integer NULL,
    CONSTRAINT pk_tbl_approval_item PRIMARY KEY (approval_item_id)
);

CREATE TABLE tbl_approval_pet (
    approval_pet_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    pet_id bigint NOT NULL,
    pet_name_id integer NOT NULL,
    pet_name varchar(30) NOT NULL,
    org_world_id integer NULL,
    org_char_id varchar(15) NULL,
    org_char_nm varchar(30) NULL,
    org_account_id varchar(15) NULL,
    org_account_nm varchar(30) NULL,
    approval_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_approval_pet PRIMARY KEY (approval_pet_id)
);

CREATE TABLE tbl_approval_skill (
    approval_skill_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    skill_id varchar(30) NOT NULL,
    skill_data1 integer NULL,
    skill_data2 integer NULL,
    approval_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_approval_skill PRIMARY KEY (approval_skill_id)
);

CREATE TABLE tbl_approval_social (
    approval_social_id integer NOT NULL,
    approval_info_id varchar(30) NOT NULL,
    emotion_type integer NOT NULL,
    expire_date integer NOT NULL,
    approval_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_approval_social PRIMARY KEY (approval_social_id)
);

CREATE TABLE tbl_bot_account_punish (
    punish_id integer NOT NULL,
    punish_group_id varchar(20) NOT NULL,
    punish_account_id integer NOT NULL,
    punish_account_name varchar(20) NULL,
    punish_code integer NOT NULL,
    punished_char_count integer NULL,
    reg_login_id varchar(20) NOT NULL,
    reg_login_nm varchar(20) NOT NULL,
    reg_date timestamp NOT NULL,
    reg_date_str varchar(19) NOT NULL,
    CONSTRAINT pk_tbl_bot_account_punish PRIMARY KEY (punish_group_id, punish_account_id)
);

CREATE TABLE tbl_bot_point_ranking (
    bot_point_ranking_id integer NOT NULL,
    world_id smallint NOT NULL,
    ranking smallint NOT NULL,
    bot_point integer NOT NULL,
    accused_count integer NOT NULL,
    char_id integer NOT NULL,
    user_id varchar(40) NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(40) NOT NULL,
    race smallint NOT NULL,
    class smallint NOT NULL,
    gender smallint NOT NULL,
    lev smallint NOT NULL,
    guild_id integer NOT NULL,
    guild_name varchar(40) NOT NULL,
    regdate timestamp NOT NULL,
    last_logout_time timestamp NULL,
    CONSTRAINT pk_tbl_bot_point_ranking PRIMARY KEY (bot_point_ranking_id)
);

CREATE TABLE tbl_builder_command_schedule (
    id integer NOT NULL,
    command_subject varchar(200) NOT NULL,
    command_text varchar(2000) NOT NULL,
    schedule_type varchar(2) NOT NULL,
    schedule_date timestamp NOT NULL,
    schedule_from timestamp NULL,
    schedule_to timestamp NULL,
    repeat_type varchar(10) NULL,
    repeat_period varchar(27) NULL,
    communication_cd varchar(5) NOT NULL,
    status char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_builder_command_schedule PRIMARY KEY (id)
);

CREATE TABLE tbl_builder_command_world (
    command_schedule_id integer NOT NULL,
    world_id integer NOT NULL,
    communication_cd varchar(5) NULL,
    execute_date timestamp NULL,
    CONSTRAINT pk_tbl_builder_command_world PRIMARY KEY (command_schedule_id, world_id)
);

CREATE TABLE tbl_charinfo_set (
    charinfo_setting_id integer NOT NULL,
    xml_title varchar(30) NOT NULL,
    xml_filename varchar(30) NOT NULL,
    xml_contents text NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    is_deleted char(1) NOT NULL,
    CONSTRAINT pk_tbl_charinfo_set PRIMARY KEY (charinfo_setting_id)
);

CREATE TABLE tbl_charinfo_set_history (
    history_id integer NOT NULL,
    charinfo_setting_id integer NOT NULL,
    world_id integer NOT NULL,
    char_id integer NOT NULL,
    char_nm varchar(20) NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    status char(3) NOT NULL,
    regdate timestamp NOT NULL,
    is_deleted char(1) NOT NULL,
    CONSTRAINT pk_tbl_charinfo_set_history PRIMARY KEY (history_id)
);

CREATE TABLE tbl_chat_search_history (
    chat_search_history_id integer NOT NULL,
    world_id smallint NOT NULL,
    char_id integer NOT NULL,
    char_nm varchar(50) NOT NULL,
    account_id varchar(15) NOT NULL,
    account_nm varchar(30) NOT NULL,
    srch_cd smallint NOT NULL,
    srch_info varchar(200) NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    char_email varchar(70) NULL,
    is_sent char(1) NOT NULL,
    cancel_memo varchar(30) NULL,
    log_contents varchar(2000) NULL,
    email_date timestamp NULL,
    char_chk_date timestamp NULL,
    from_date timestamp NOT NULL,
    to_date timestamp NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_chat_search_history PRIMARY KEY (chat_search_history_id)
);

CREATE TABLE tbl_forbidden (
    forbidden_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    pub_status char(3) NOT NULL,
    forbidden_type char(2) NOT NULL,
    servers varchar(200) NOT NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_game_notice_contents (
    notice_contents_id integer NOT NULL,
    notice_id varchar(30) NOT NULL,
    notice_sentence varchar(200) NULL,
    CONSTRAINT pk_tbl_game_notice_contents PRIMARY KEY (notice_contents_id)
);

CREATE TABLE tbl_game_notice_history (
    notice_history_id integer NOT NULL,
    notice_id varchar(30) NOT NULL,
    world_id integer NOT NULL,
    communication_cd varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_game_notice_history PRIMARY KEY (notice_history_id)
);

CREATE TABLE tbl_game_notice_preset (
    id integer NOT NULL,
    notice_subject varchar(200) NOT NULL,
    notice_category char(1) NOT NULL,
    notice_type char(2) NOT NULL,
    notice_pos_type char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    notice_race varchar(100) NULL,
    notice_class varchar(300) NULL,
    status char(1) NOT NULL,
    CONSTRAINT pk_tbl_game_notice_preset PRIMARY KEY (id)
);

CREATE TABLE tbl_game_notice_preset_contents (
    id integer NOT NULL,
    preset_id integer NOT NULL,
    sentence varchar(200) NOT NULL,
    CONSTRAINT pk_tbl_game_notice_preset_contents PRIMARY KEY (id)
);

CREATE TABLE tbl_game_notice_schedule (
    notice_id varchar(30) NOT NULL,
    notice_category char(1) NOT NULL,
    notice_subject varchar(200) NULL,
    notice_type char(2) NOT NULL,
    notice_from timestamp NULL,
    notice_to timestamp NULL,
    notice_period varchar(10) NOT NULL,
    notice_repeat integer NOT NULL,
    notice_repeat_min integer NOT NULL,
    notice_week varchar(20) NULL,
    notice_month integer NULL,
    period_hour integer NOT NULL,
    period_min integer NOT NULL,
    notice_pos_type char(1) NOT NULL,
    communication_cd varchar(30) NOT NULL,
    notice_count integer NULL,
    notice_status char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    notice_race varchar(100) NULL,
    notice_class varchar(300) NULL,
    CONSTRAINT pk_tbl_game_notice_schedule PRIMARY KEY (notice_id)
);

CREATE TABLE tbl_game_notice_world (
    notice_world_id integer NOT NULL,
    notice_id varchar(30) NOT NULL,
    world_id integer NOT NULL,
    CONSTRAINT pk_tbl_game_notice_world PRIMARY KEY (notice_world_id)
);

CREATE TABLE tbl_game_server_info (
    world_id smallint NOT NULL,
    server_id smallint NOT NULL,
    server_status smallint NOT NULL,
    free_disk smallint NOT NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_game_world_info (
    world_id smallint NOT NULL,
    world_type varchar(50) NULL,
    zone_id integer NOT NULL,
    zone_nm varchar(50) NOT NULL,
    channel_num varchar(10) NULL,
    light_users integer NULL,
    dark_users integer NULL,
    npc_count integer NULL,
    pc_store_light_users integer NULL,
    pc_store_dark_users integer NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_group_func (
    group_func_id integer NOT NULL,
    group_id varchar(20) NOT NULL,
    menu_id integer NOT NULL,
    search_auth char(1) NOT NULL,
    view_auth char(1) NOT NULL,
    insert_auth char(1) NOT NULL,
    update_auth char(1) NOT NULL,
    delete_auth char(1) NOT NULL,
    CONSTRAINT pk_tbl_group_func PRIMARY KEY (group_func_id)
);

CREATE TABLE tbl_item_change_info (
    item_change_info_id integer NOT NULL,
    main_type smallint NOT NULL,
    sub_type varchar(5) NOT NULL,
    info_id integer NOT NULL,
    plus_value bigint NOT NULL,
    minus_value bigint NOT NULL,
    status smallint NOT NULL,
    regdate timestamp NOT NULL,
    world_id smallint NULL,
    char_id integer NULL,
    CONSTRAINT pk_tbl_item_change_info PRIMARY KEY (item_change_info_id)
);

CREATE TABLE tbl_item_preset (
    preset_id varchar(20) NOT NULL,
    preset_nm varchar(50) NOT NULL,
    is_deleted char(1) NOT NULL,
    regdate timestamp NOT NULL,
    login_id varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_item_preset PRIMARY KEY (preset_id)
);

CREATE TABLE tbl_log_files (
    logfile_id integer NOT NULL,
    logfile_type varchar(20) NOT NULL,
    logfile_name varchar(80) NOT NULL,
    logfile_size varchar(20) NOT NULL,
    logfile_info varchar(500) NOT NULL,
    is_shared char(1) NOT NULL,
    is_deleted char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_log_files PRIMARY KEY (logfile_id)
);

CREATE TABLE tbl_mail (
    mail_id integer NOT NULL,
    mail_type varchar(20) NOT NULL,
    mail_title varchar(80) NOT NULL,
    mail_intro varchar(200) NOT NULL,
    mail_content varchar(400) NOT NULL,
    mail_tail varchar(200) NOT NULL,
    mail_status char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_mail PRIMARY KEY (mail_id)
);

CREATE TABLE tbl_mail_shoot_history (
    mail_id varchar(30) NOT NULL,
    world_id integer NOT NULL,
    char_nms varchar(3000) NULL,
    mail_subject varchar(100) NOT NULL,
    mail_content varchar(1000) NOT NULL,
    mail_kina bigint NULL,
    mail_name_id integer NULL,
    mail_amount bigint NULL,
    mail_express smallint NOT NULL,
    err_info varchar(1000) NOT NULL,
    reason varchar(200) NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    status char(3) NOT NULL,
    regdate timestamp NOT NULL,
    is_deleted char(1) NOT NULL,
    CONSTRAINT pk_tbl_mail_shoot_history PRIMARY KEY (mail_id)
);

CREATE TABLE tbl_memo (
    memo_id integer NOT NULL,
    menu_id integer NOT NULL,
    ref_pk_id varchar(30) NOT NULL,
    char_nm varchar(50) NULL,
    memo_info text NOT NULL,
    memo_status char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    world_id integer NULL,
    regdate timestamp NOT NULL,
    memo_type char(1) NULL,
    CONSTRAINT pk_tbl_memo PRIMARY KEY (memo_id)
);

CREATE TABLE tbl_my_func (
    auth_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    menu_id integer NOT NULL,
    search_auth char(1) NOT NULL,
    view_auth char(1) NOT NULL,
    insert_auth char(1) NOT NULL,
    update_auth char(1) NOT NULL,
    delete_auth char(1) NOT NULL,
    reg_login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    is_deleted char(1) NOT NULL,
    CONSTRAINT pk_tbl_my_func PRIMARY KEY (auth_id)
);

CREATE TABLE tbl_my_group (
    mygroup_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    group_id varchar(20) NOT NULL,
    CONSTRAINT pk_tbl_my_group PRIMARY KEY (mygroup_id)
);

CREATE TABLE tbl_my_world (
    my_world_id integer NOT NULL,
    world_id integer NOT NULL,
    login_id varchar(30) NOT NULL,
    server_type smallint NULL,
    CONSTRAINT pk_tbl_my_world PRIMARY KEY (my_world_id)
);

CREATE TABLE tbl_mypreset (
    mypreset_id integer NOT NULL,
    preset_id varchar(20) NOT NULL,
    log_id integer NOT NULL,
    category_code varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_mypreset PRIMARY KEY (mypreset_id)
);

CREATE TABLE tbl_pc_copy (
    pccopy_id integer NOT NULL,
    target_world_id smallint NULL,
    target_char_id integer NULL,
    target_char_nm varchar(20) NULL,
    target_account_id integer NULL,
    target_account_name varchar(14) NULL,
    target_char_gender smallint NULL,
    target_char_race smallint NULL,
    target_char_class smallint NULL,
    target_char_lev smallint NULL,
    src_world_id smallint NULL,
    src_char_id integer NULL,
    src_char_nm varchar(20) NULL,
    src_account_id integer NULL,
    src_account_name varchar(14) NULL,
    src_char_gender smallint NULL,
    src_char_race smallint NULL,
    src_char_class smallint NULL,
    src_char_lev smallint NULL,
    status smallint NOT NULL,
    move_type smallint NOT NULL,
    memo varchar(300) NULL,
    movedate timestamp NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_pc_copy PRIMARY KEY (pccopy_id)
);

CREATE TABLE tbl_poll (
    poll_id integer NOT NULL,
    poll_title varchar(200) NOT NULL,
    poll_xml_filename varchar(100) NOT NULL,
    poll_xml_contents text NULL,
    poll_servers varchar(300) NOT NULL,
    poll_cnt integer NOT NULL,
    poll_status char(3) NOT NULL,
    poll_start_date timestamp NOT NULL,
    poll_end_date timestamp NOT NULL,
    order_num smallint NULL,
    race varchar(100) NULL,
    poll_level varchar(50) NULL,
    is_deleted char(1) NOT NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_poll_server (
    poll_id integer NOT NULL,
    world_id integer NOT NULL,
    pub_status char(3) NOT NULL,
    start_date timestamp NOT NULL,
    end_date timestamp NOT NULL,
    gathering_date timestamp NOT NULL,
    poll_cnt integer NOT NULL,
    rs_file_name varchar(50) NOT NULL,
    regdate timestamp NOT NULL
);

CREATE TABLE tbl_preset (
    preset_id varchar(20) NOT NULL,
    preset_nm varchar(50) NOT NULL,
    is_shared char(1) NOT NULL,
    is_deleted char(1) NOT NULL,
    regdate timestamp NOT NULL,
    login_id varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_preset PRIMARY KEY (preset_id)
);

CREATE TABLE tbl_preset_item_id (
    item_preset_id integer NOT NULL,
    preset_id varchar(20) NOT NULL,
    item_id integer NOT NULL,
    item_cnt bigint NOT NULL,
    item_pkg_cnt integer NOT NULL,
    item_enchant smallint NOT NULL,
    CONSTRAINT pk_tbl_preset_item_id PRIMARY KEY (item_preset_id)
);

CREATE TABLE tbl_quest (
    quest_pk integer NOT NULL,
    quest_req_id varchar(30) NOT NULL,
    quest_id integer NOT NULL,
    quest_status integer NOT NULL,
    quest_progress integer NOT NULL,
    quest_branch smallint NOT NULL,
    char_id varchar(15) NOT NULL,
    char_nm varchar(50) NULL,
    account_id varchar(15) NOT NULL,
    world_id integer NOT NULL,
    request_type varchar(30) NOT NULL,
    quest_req_info varchar(400) NOT NULL,
    communication_cd varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    quest_count integer DEFAULT 0 NULL,
    CONSTRAINT pk_tbl_quest PRIMARY KEY (quest_pk)
);

CREATE TABLE tbl_special_func (
    special_func_id integer NOT NULL,
    menu_id integer NOT NULL,
    special_func_cd varchar(30) NOT NULL,
    special_func_desc varchar(300) NOT NULL,
    CONSTRAINT pk_tbl_special_func PRIMARY KEY (special_func_id)
);

CREATE TABLE tbl_special_group (
    special_group_id integer NOT NULL,
    group_id varchar(20) NOT NULL,
    special_func_id integer NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_special_group PRIMARY KEY (special_group_id)
);

CREATE TABLE tbl_statistics_history (
    statistics_history_id integer NOT NULL,
    statistics_id varchar(30) NOT NULL,
    world_id integer NOT NULL,
    task_cd varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_statistics_history PRIMARY KEY (statistics_history_id)
);

CREATE TABLE tbl_statistics_poll (
    world_id integer NOT NULL,
    poll_id integer NOT NULL,
    char_id integer NOT NULL,
    user_id varchar(20) NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(20) NOT NULL,
    class smallint NOT NULL,
    race smallint NOT NULL,
    world integer NOT NULL,
    xlocation real NOT NULL,
    ylocation real NOT NULL,
    zlocation real NOT NULL,
    lev smallint NOT NULL,
    answer_time timestamp NOT NULL,
    answer varchar(3500) NOT NULL
);

CREATE TABLE tbl_statistics_schedule (
    statistics_id varchar(30) NOT NULL,
    statistics_cmd varchar(30) NOT NULL,
    statistics_category varchar(30) NOT NULL,
    statistics_subject varchar(200) NOT NULL,
    statistics_from timestamp NULL,
    statistics_to timestamp NULL,
    statistics_period varchar(10) NOT NULL,
    statistics_repeat integer NOT NULL,
    statistics_repeat_min integer NOT NULL,
    statistics_week varchar(20) NULL,
    statistics_month integer NULL,
    period_hour integer NOT NULL,
    period_min integer NOT NULL,
    task_cd varchar(30) NOT NULL,
    statistics_status char(1) NOT NULL,
    login_id varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_statistics_schedule PRIMARY KEY (statistics_id)
);

CREATE TABLE tbl_statistics_world (
    statistics_world_id integer NOT NULL,
    statistics_id varchar(30) NOT NULL,
    world_id integer NOT NULL,
    CONSTRAINT pk_tbl_statistics_world PRIMARY KEY (statistics_world_id)
);

CREATE TABLE tbl_workflow_list (
    workflow_cd varchar(30) NOT NULL,
    workflow_nm varchar(50) NOT NULL,
    workflow_type varchar(30) NOT NULL,
    CONSTRAINT pk_tbl_workflow_list PRIMARY KEY (workflow_cd)
);

CREATE TABLE tbl_world_concurrent_info (
    concurrent_info_id integer NOT NULL,
    world_id integer NOT NULL,
    max_concurrent_users varchar(20) NOT NULL,
    min_concurrent_users varchar(20) NOT NULL,
    max_cpu_usage integer NOT NULL,
    max_free_phy_memory varchar(20) NOT NULL,
    max_process_memory varchar(20) NOT NULL,
    min_cpu_usage integer NOT NULL,
    min_free_phy_memory varchar(20) NOT NULL,
    min_process_memory varchar(20) NOT NULL,
    max_regdate timestamp NOT NULL,
    min_regdate timestamp NOT NULL,
    CONSTRAINT pk_tbl_world_concurrent_info PRIMARY KEY (concurrent_info_id)
);

CREATE TABLE tbl_world_info (
    world_id integer NOT NULL,
    world_nm varchar(50) NOT NULL,
    world_desc varchar(300) NULL,
    world_status char(1) NOT NULL,
    server_type smallint NULL
);

CREATE TABLE tbl_world_server_info (
    server_id integer NOT NULL,
    world_id integer NOT NULL,
    server_nm varchar(50) NOT NULL,
    server_url varchar(200) NOT NULL,
    server_desc varchar(300) NOT NULL,
    server_status char(1) NOT NULL,
    CONSTRAINT pk_tbl_world_server_info PRIMARY KEY (server_id)
);

CREATE TABLE tbl_world_status_info (
    world_status_info_id integer NOT NULL,
    world_id integer NOT NULL,
    server_nm integer NOT NULL,
    concurrent_users varchar(20) NOT NULL,
    cpu_usage integer NOT NULL,
    free_phy_memory varchar(20) NOT NULL,
    process_memory varchar(20) NOT NULL,
    regdate timestamp NOT NULL,
    db_free double precision NOT NULL
);

-- ── Indexes ──────────────────────────────────────────

CREATE INDEX tbl_admin_log_201802_copy1 ON tbl_admin_log_202009 (regdate);
CREATE UNIQUE INDEX uk_tbl_admin_menu ON tbl_admin_menu (menu_code);
CREATE UNIQUE INDEX uk_tbl_admin_user ON tbl_admin_user (login_id);
CREATE INDEX ix_login_id ON tbl_admin_user_pw_history (login_id);
CREATE INDEX ix_regdate_world_id ON tbl_alert_event (regdate, world_id);
CREATE INDEX ix_login_id_tbl_approval_info ON tbl_approval_info (login_id);
CREATE INDEX ix_world_id_char_id ON tbl_approval_info (world_id, approval_char_id);
CREATE INDEX idx_tbl_bot_account_punish ON tbl_bot_account_punish (punish_group_id, punish_account_id, reg_date_str);
CREATE INDEX ix_game_notice_preset_contents ON tbl_game_notice_preset_contents (preset_id);
CREATE INDEX idx_tbl_poll ON tbl_poll (poll_id);
CREATE INDEX ncl_tbl_poll_server ON tbl_poll_server (poll_id, world_id);
CREATE INDEX ix_tbl_statistics_poll ON tbl_statistics_poll (poll_id, world_id);

-- ── Foreign Keys ─────────────────────────────────────

ALTER TABLE tbl_group_func ADD CONSTRAINT fk_tbl_group_func_01 FOREIGN KEY (group_id) REFERENCES tbl_admin_group (group_id);
ALTER TABLE tbl_special_group ADD CONSTRAINT fk_tbl_special_group_02 FOREIGN KEY (group_id) REFERENCES tbl_admin_group (group_id);
ALTER TABLE tbl_group_func ADD CONSTRAINT fk_tbl_group_func_02 FOREIGN KEY (menu_id) REFERENCES tbl_admin_menu (menu_id);
ALTER TABLE tbl_my_func ADD CONSTRAINT fk_tbl_my_func_02 FOREIGN KEY (menu_id) REFERENCES tbl_admin_menu (menu_id);
ALTER TABLE tbl_special_func ADD CONSTRAINT fk_tbl_special_func_01 FOREIGN KEY (menu_id) REFERENCES tbl_admin_menu (menu_id);
ALTER TABLE tbl_approval_default_stage ADD CONSTRAINT fk_tbl_approval_default_stage_03 FOREIGN KEY (organization_id) REFERENCES tbl_admin_organization (organization_id);
ALTER TABLE tbl_admin_user ADD CONSTRAINT fk_tbl_admin_user_01 FOREIGN KEY (organization_id) REFERENCES tbl_admin_organization (organization_id);
ALTER TABLE tbl_admin_user_history ADD CONSTRAINT fk_tbl_admin_user_history FOREIGN KEY (admin_id) REFERENCES tbl_admin_user (admin_id);
ALTER TABLE tbl_approval_default_stage ADD CONSTRAINT fk_tbl_approval_default_stage_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_approval_history ADD CONSTRAINT fk_tbl_approval_history_02 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_approval_info ADD CONSTRAINT fk_tbl_approval_info_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_game_notice_schedule ADD CONSTRAINT fk_tbl_game_notice_schedule_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_log_files ADD CONSTRAINT fk_tbl_log_files_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_my_func ADD CONSTRAINT fk_tbl_my_func_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_my_func ADD CONSTRAINT fk_tbl_my_func_03 FOREIGN KEY (reg_login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_my_group ADD CONSTRAINT fk_tbl_my_group_02 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_my_world ADD CONSTRAINT fk_tbl_my_world_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_preset ADD CONSTRAINT fk_tbl_preset_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_statistics_schedule ADD CONSTRAINT fk_tbl_statistics_schedule_01 FOREIGN KEY (login_id) REFERENCES tbl_admin_user (login_id);
ALTER TABLE tbl_approval_animation ADD CONSTRAINT fk_tbl_approval_animation FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_guild ADD CONSTRAINT fk_tbl_approval_guild FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_history ADD CONSTRAINT fk_tbl_approval_history_01 FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_item ADD CONSTRAINT fk_tbl_approval_item_01 FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_pet ADD CONSTRAINT fk_tbl_approval_pet_01 FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_skill ADD CONSTRAINT fk_tbl_approval_skill_01 FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_approval_social ADD CONSTRAINT fk_tbl_approval_social FOREIGN KEY (approval_info_id) REFERENCES tbl_approval_info (approval_info_id);
ALTER TABLE tbl_charinfo_set_history ADD CONSTRAINT fk_tbl_charinfo_set_history_01 FOREIGN KEY (charinfo_setting_id) REFERENCES tbl_charinfo_set (charinfo_setting_id);
ALTER TABLE tbl_game_notice_contents ADD CONSTRAINT fk_tbl_game_notice_contents_01 FOREIGN KEY (notice_id) REFERENCES tbl_game_notice_schedule (notice_id);
ALTER TABLE tbl_game_notice_history ADD CONSTRAINT fk_tbl_game_notice_history_01 FOREIGN KEY (notice_id) REFERENCES tbl_game_notice_schedule (notice_id);
ALTER TABLE tbl_mypreset ADD CONSTRAINT fk_tbl_mypreset_01 FOREIGN KEY (preset_id) REFERENCES tbl_preset (preset_id);
ALTER TABLE tbl_special_group ADD CONSTRAINT fk_tbl_special_group_01 FOREIGN KEY (special_func_id) REFERENCES tbl_special_func (special_func_id);
ALTER TABLE tbl_statistics_history ADD CONSTRAINT fk_tbl_statistics_history_01 FOREIGN KEY (statistics_id) REFERENCES tbl_statistics_schedule (statistics_id);
ALTER TABLE tbl_approval_default_stage ADD CONSTRAINT fk_tbl_approval_default_stage_02 FOREIGN KEY (workflow_cd) REFERENCES tbl_workflow_list (workflow_cd);
ALTER TABLE tbl_approval_info ADD CONSTRAINT fk_tbl_approval_info_02 FOREIGN KEY (workflow_cd) REFERENCES tbl_workflow_list (workflow_cd);
