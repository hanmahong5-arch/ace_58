-- PostgreSQL DDL for database: aion_world_live
-- Generated from SQL Server schema: AionWorldLive
-- Tables: 171

CREATE TABLE abyss (
    abyss_id integer NOT NULL,
    owner_guild integer DEFAULT 0 NOT NULL,
    owner_race smallint DEFAULT 0 NOT NULL,
    defense_count integer DEFAULT 0 NOT NULL,
    reward bigint DEFAULT 0 NOT NULL,
    cur_pvp_status smallint DEFAULT 0 NOT NULL,
    next_pvp_status smallint DEFAULT 0 NOT NULL,
    door_upgrade_point integer DEFAULT 0 NOT NULL,
    shield_upgrade_point integer DEFAULT 0 NOT NULL,
    peace_count smallint DEFAULT 0 NOT NULL,
    occupy_bonus bigint DEFAULT 0 NOT NULL,
    change_owner_time integer DEFAULT 0 NOT NULL,
    user_reward_sum bigint DEFAULT 0 NOT NULL,
    owner_char_id integer DEFAULT '0' NOT NULL,
    last_ownership_bonus_gp integer DEFAULT '0' NOT NULL,
    owner_server integer DEFAULT 0 NOT NULL,
    last_pvp_on_time integer DEFAULT 0 NOT NULL,
    occupy_point smallint DEFAULT 0 NOT NULL,
    occupy_count integer DEFAULT 0 NOT NULL,
    occupy_reward_count_l smallint DEFAULT 0 NOT NULL,
    occupy_reward_count_d smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_abyss PRIMARY KEY (abyss_id)
);

CREATE TABLE abyss_manage (
    last_pvp_calc_time integer DEFAULT 0 NOT NULL
);

CREATE TABLE abyss_op_point (
    race smallint NOT NULL,
    quest integer NOT NULL,
    fortress integer NOT NULL,
    artifact integer NOT NULL,
    basecamp integer NOT NULL,
    op_object integer NOT NULL,
    raid_object integer NOT NULL,
    ownership_object integer NOT NULL,
    next_reset_time bigint NOT NULL
);

CREATE TABLE abyss_op_spawn (
    npc_name_id integer NOT NULL,
    spawn smallint NOT NULL,
    last_update_time timestamp NOT NULL
);

CREATE TABLE abyss_ranking (
    abyss_ranking integer DEFAULT 0 NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    update_time bigint NOT NULL,
    char_id integer NOT NULL,
    abyss_point bigint NOT NULL,
    race smallint NOT NULL,
    class smallint DEFAULT 0 NOT NULL,
    lev smallint DEFAULT 0 NOT NULL,
    guild_id integer DEFAULT 0 NOT NULL,
    "rank" integer DEFAULT 0 NOT NULL,
    old_ranking integer DEFAULT 0 NOT NULL,
    rank_updatedate timestamp NULL,
    gp integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_abyss_ranking PRIMARY KEY (update_time, char_id)
);

CREATE TABLE abyss_region_ranking (
    "rank" integer NULL,
    old_rank integer NULL,
    id integer NULL,
    race integer NULL,
    "level" integer NULL,
    cnt integer NULL,
    point bigint NULL,
    "name" varchar(32) NULL,
    updatetime integer NULL,
    uid integer NOT NULL,
    CONSTRAINT pk_abyss_region_ranking PRIMARY KEY (uid)
);

CREATE TABLE abyss_reward_update_time (
    guild_week_reward_time bigint DEFAULT 0 NOT NULL,
    guild_season_reward_time bigint DEFAULT 0 NOT NULL,
    guild_winner_light integer DEFAULT 0 NOT NULL,
    guild_winner_dark integer DEFAULT 0 NOT NULL,
    user_week_reward_time bigint DEFAULT 0 NOT NULL
);

CREATE TABLE abyss_user_defender (
    abyss_id integer NOT NULL,
    defender_char_id integer NOT NULL,
    defender_share_amount bigint NOT NULL,
    defender_rank integer NOT NULL,
    update_time integer NOT NULL,
    defender_siegepoint integer DEFAULT 0 NOT NULL,
    group_id integer DEFAULT 0 NOT NULL,
    defender_server_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_abyss_user_defender PRIMARY KEY (defender_char_id, update_time, abyss_id)
);

CREATE TABLE abyss_user_owner (
    abyss_id integer NOT NULL,
    owner_char_id integer NOT NULL,
    owner_share_amount bigint NOT NULL,
    owner_rank integer NOT NULL,
    update_time integer NOT NULL,
    owner_siegepoint integer DEFAULT 0 NOT NULL,
    group_id integer DEFAULT 0 NOT NULL,
    owner_server_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_abyss_user_owner PRIMARY KEY (owner_char_id, update_time, abyss_id)
);

CREATE TABLE access_allow_account (
    access_id integer NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(14) NOT NULL,
    status smallint NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_access_allow_account PRIMARY KEY (access_id)
);

CREATE TABLE aion_tv_contents (
    id integer NOT NULL,
    server_id integer NOT NULL,
    url varchar(512) NULL,
    start_date bigint NULL,
    end_date bigint NULL,
    login_id varchar(30) NULL,
    login_nm varchar(30) NULL,
    reg_date timestamp NULL,
    is_deleted smallint NULL,
    CONSTRAINT pk_aion_tv_contents PRIMARY KEY (id, server_id)
);

CREATE TABLE aionaddedservice (
    idx integer NOT NULL,
    postdate timestamp NOT NULL,
    applydate timestamp NULL,
    servicetype smallint NOT NULL,
    ssn char(13) NULL,
    fromuid integer NOT NULL,
    touid integer NULL,
    fromaccount varchar(14) NOT NULL,
    toaccount varchar(14) NULL,
    fromserver smallint NOT NULL,
    toserver smallint NULL,
    fromcharacter varchar(24) NOT NULL,
    tocharacter varchar(24) NULL,
    changegender boolean NULL,
    billmethod integer NULL,
    status smallint NOT NULL,
    serviceflag smallint NOT NULL,
    reserve1 varchar(200) NULL,
    reserve2 varchar(100) NULL,
    canceldate timestamp NULL,
    fromcharacterid integer NULL,
    tocharacterid integer NULL,
    fromrace smallint NULL,
    torace smallint NULL,
    warehouse smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_aionaddedservice PRIMARY KEY (idx)
);

CREATE TABLE aionaddedservice_servername (
    server_id integer NOT NULL,
    datasource varchar(128) NOT NULL,
    database_name varchar(64) NOT NULL
);

CREATE TABLE aionbulkquestmaxrepeat (
    questid integer NULL,
    maxrepeat integer NULL
);

CREATE TABLE aiondeletedeventitemcount (
    char_id integer NOT NULL,
    item_count bigint NOT NULL,
    apply_date timestamp NOT NULL,
    event_item bigint NOT NULL
);

CREATE TABLE bookmark (
    bookmark_id integer NOT NULL,
    char_id integer NOT NULL,
    bookmark varchar(30) NOT NULL,
    world integer NOT NULL,
    x real NOT NULL,
    y real NOT NULL,
    z real NOT NULL,
    CONSTRAINT pk_bookmark PRIMARY KEY (bookmark_id)
);

CREATE TABLE builder_log (
    builder_log_id integer NOT NULL,
    world_id integer NOT NULL,
    char_nm varchar(20) NOT NULL,
    build_nm varchar(256) NOT NULL,
    build_parameter varchar(512) NOT NULL,
    builder_type smallint NOT NULL,
    builder_lv smallint NOT NULL,
    regdate timestamp NOT NULL,
    target_char_nm varchar(20) NULL,
    command_from smallint NULL,
    result_message varchar(1024) NULL,
    CONSTRAINT pk_builder_log PRIMARY KEY (builder_log_id)
);

CREATE TABLE challenge_task (
    id bigint NOT NULL,
    union_id integer NOT NULL,
    task_name_id integer NOT NULL,
    "type" smallint DEFAULT 0 NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    complete_count smallint DEFAULT 0 NOT NULL,
    last_complete_time integer NOT NULL,
    CONSTRAINT pk_challenge_task PRIMARY KEY (id)
);

CREATE TABLE challenge_task_contributor (
    challenge_task_id bigint NOT NULL,
    contributor_id integer NOT NULL,
    contributor_name varchar(40) NOT NULL,
    score bigint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_challenge_task_contributor PRIMARY KEY (challenge_task_id, contributor_id)
);

CREATE TABLE challenge_task_quest (
    challenge_task_id bigint NOT NULL,
    quest_id integer NOT NULL,
    complete_count smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_challenge_task_quest PRIMARY KEY (challenge_task_id, quest_id)
);

CREATE TABLE enchant_migration (
    nameid integer NULL,
    enchant smallint NULL,
    "value" integer NULL
);

CREATE TABLE error_ignore (
    id integer NOT NULL,
    ignore varchar(256) NULL,
    CONSTRAINT pk_error_ignore PRIMARY KEY (id)
);

CREATE TABLE export_item_log (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    export_to_sv integer NOT NULL,
    export_to_id bigint NOT NULL,
    export_date integer NOT NULL,
    CONSTRAINT pk_export_item_log PRIMARY KEY (id)
);

CREATE TABLE forbidden_char (
    forbidden_id integer NOT NULL,
    forbidden_type smallint NOT NULL,
    forbidden_reason smallint NOT NULL,
    world_id smallint NOT NULL,
    forbidden_char varchar(30) NOT NULL,
    forbidden_account_nm varchar(40) NOT NULL,
    status smallint NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_forbidden_char PRIMARY KEY (forbidden_id)
);

CREATE TABLE forbidden_word (
    forbidden_id integer NOT NULL,
    forbidden_type smallint NOT NULL,
    forbidden_reason smallint NOT NULL,
    world_id smallint NOT NULL,
    forbidden_word varchar(32) NOT NULL,
    status smallint NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    is_like smallint NULL,
    CONSTRAINT pk_forbidden_word PRIMARY KEY (forbidden_id)
);

CREATE TABLE game_money_trade (
    id bigint NOT NULL,
    seller integer NOT NULL,
    qina bigint NOT NULL,
    cash bigint NOT NULL,
    state smallint NULL,
    register_date timestamp NULL,
    complete_date timestamp NULL,
    buyer integer NULL,
    request_id varchar(68) NULL,
    reward_seller smallint NULL,
    CONSTRAINT pk_game_money_trade PRIMARY KEY (id)
);

CREATE TABLE gpforbid2 (
    word varchar(32) NOT NULL
);

CREATE TABLE guild (
    id integer NOT NULL,
    "name" varchar(32) NOT NULL,
    race smallint DEFAULT 0 NOT NULL,
    master_id integer NOT NULL,
    "level" smallint DEFAULT 1 NOT NULL,
    "rank" integer DEFAULT 0 NOT NULL,
    point bigint DEFAULT 0 NOT NULL,
    fund bigint DEFAULT 0 NOT NULL,
    officer_right smallint DEFAULT 7176 NOT NULL,
    member_right smallint DEFAULT 6144 NOT NULL,
    delete_requested smallint NOT NULL,
    delete_time integer DEFAULT 0 NOT NULL,
    emblem bytea NULL,
    notice1 varchar(256) NOT NULL,
    notice2 varchar(256) NOT NULL,
    notice3 varchar(256) NOT NULL,
    notice4 varchar(256) NOT NULL,
    notice5 varchar(256) NOT NULL,
    notice6 varchar(256) NOT NULL,
    notice7 varchar(256) DEFAULT NULL NOT NULL,
    noticetime1 integer DEFAULT 0 NOT NULL,
    noticetime2 integer DEFAULT 0 NOT NULL,
    noticetime3 integer DEFAULT 0 NOT NULL,
    noticetime4 integer DEFAULT 0 NOT NULL,
    noticetime5 integer DEFAULT 0 NOT NULL,
    noticetime6 integer DEFAULT 0 NOT NULL,
    noticetime7 integer DEFAULT 0 NOT NULL,
    emblem_img_version smallint DEFAULT 0 NOT NULL,
    emblem_img bytea NULL,
    emblem_img_last_version smallint DEFAULT 0 NOT NULL,
    emblem_bgcolor integer DEFAULT 0 NOT NULL,
    old_rank integer DEFAULT 0 NOT NULL,
    change_info_time bigint DEFAULT 0 NOT NULL,
    submaster_right smallint DEFAULT 7692 NOT NULL,
    newbie_right smallint DEFAULT 2048 NOT NULL,
    point_max_time bigint DEFAULT 0 NOT NULL,
    this_week_tld integer DEFAULT 0 NOT NULL,
    last_week_tld integer DEFAULT 0 NOT NULL,
    tld_update_time bigint DEFAULT 0 NOT NULL,
    intro varchar(32) DEFAULT '' NOT NULL,
    join_process_type smallint DEFAULT 0 NOT NULL,
    join_restrict_level smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_guild PRIMARY KEY (id)
);

CREATE TABLE guild_history (
    id integer NOT NULL,
    guild_id integer NOT NULL,
    eventdate integer NOT NULL,
    eventtype smallint NOT NULL,
    eventparam varchar(100) NOT NULL,
    eventparam2 varchar(100) DEFAULT '' NOT NULL,
    CONSTRAINT pk_guild_history PRIMARY KEY (id)
);

CREATE TABLE guild_item (
    guild_id integer DEFAULT 0 NOT NULL,
    item_id bigint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_guild_item PRIMARY KEY (guild_id, item_id)
);

CREATE TABLE guild_item_lost (
    guild_id integer NULL,
    item_id bigint NULL
);

CREATE TABLE guild_name_change_log (
    id integer NOT NULL,
    guild_id integer NOT NULL,
    old_name varchar(32) NOT NULL,
    new_name varchar(32) NOT NULL,
    change_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    item_id bigint NOT NULL,
    tid bigint DEFAULT 0 NOT NULL,
    master_id integer DEFAULT 0 NOT NULL,
    master_user_id varchar(20) DEFAULT '' NOT NULL,
    master_account_id integer DEFAULT 0 NOT NULL,
    master_account_name varchar(14) DEFAULT '' NOT NULL,
    race smallint DEFAULT 0 NOT NULL,
    class smallint DEFAULT 0 NOT NULL,
    gender boolean DEFAULT false NOT NULL,
    lev smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_guild_name_change_log PRIMARY KEY (id)
);

CREATE TABLE guild_warehouse_history (
    id integer NOT NULL,
    guild_id integer NOT NULL,
    eventdate integer NOT NULL,
    eventtype smallint NOT NULL,
    eventparam varchar(100) NOT NULL,
    eventparam2 varchar(100) DEFAULT '' NOT NULL,
    CONSTRAINT pk_guild_warehouse_history PRIMARY KEY (id)
);

CREATE TABLE house_addrinfo (
    addr_id integer NOT NULL,
    land_nameid integer NOT NULL,
    world_id integer NULL,
    center_x double precision NULL,
    center_y double precision NULL,
    center_z double precision NULL,
    CONSTRAINT pk_house_addrinfo PRIMARY KEY (addr_id)
);

CREATE TABLE house_field (
    id integer NOT NULL,
    addr_id integer NOT NULL,
    building_nameid integer NOT NULL,
    owner_id integer NOT NULL,
    owner_type smallint NOT NULL,
    owner_race smallint NOT NULL,
    state smallint NOT NULL,
    permission smallint NOT NULL,
    comment_state smallint NULL,
    roof integer DEFAULT 0 NULL,
    outwall integer DEFAULT 0 NULL,
    frame integer DEFAULT 0 NULL,
    door integer DEFAULT 0 NULL,
    garden integer DEFAULT 0 NULL,
    fence integer DEFAULT 0 NULL,
    inwall1 integer DEFAULT 0 NULL,
    inwall2 integer DEFAULT 0 NULL,
    inwall3 integer DEFAULT 0 NULL,
    inwall4 integer DEFAULT 0 NULL,
    inwall5 integer DEFAULT 0 NULL,
    inwall6 integer DEFAULT 0 NULL,
    infloor1 integer DEFAULT 0 NULL,
    infloor2 integer DEFAULT 0 NULL,
    infloor3 integer DEFAULT 0 NULL,
    infloor4 integer DEFAULT 0 NULL,
    infloor5 integer DEFAULT 0 NULL,
    infloor6 integer DEFAULT 0 NULL,
    addon1 integer DEFAULT 0 NULL,
    addon2 integer DEFAULT 0 NULL,
    addon3 integer DEFAULT 0 NULL,
    flag1 boolean DEFAULT false NULL,
    flag2 boolean DEFAULT false NULL,
    flag3 boolean DEFAULT false NULL,
    flag4 boolean DEFAULT false NULL,
    flag5 boolean DEFAULT false NULL,
    flag6 boolean DEFAULT false NULL,
    flag7 boolean DEFAULT false NULL,
    "comment" varchar(64) NULL,
    chargecount integer DEFAULT 1 NOT NULL,
    warningcount integer DEFAULT 0 NOT NULL,
    lastcharge integer DEFAULT 0 NOT NULL,
    update_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    created_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    owner_name varchar(32) NULL,
    legion_id integer DEFAULT 0 NOT NULL,
    emblem_version smallint DEFAULT 0 NOT NULL,
    emblem_bgcolor integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_house_field PRIMARY KEY (addr_id)
);

CREATE TABLE house_field_script (
    addr_id integer NOT NULL,
    slot_id integer NOT NULL,
    script_size smallint NULL,
    script_data bytea NULL,
    CONSTRAINT pk_house_field_script PRIMARY KEY (addr_id, slot_id)
);

CREATE TABLE house_instant (
    id integer NOT NULL,
    state smallint NOT NULL,
    permission smallint NOT NULL,
    inwall integer DEFAULT 0 NULL,
    infloor integer DEFAULT 0 NULL,
    update_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    created_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    CONSTRAINT pk_house_instant PRIMARY KEY (id)
);

CREATE TABLE house_instant_script (
    char_id integer NOT NULL,
    slot_id integer NOT NULL,
    script_size smallint NULL,
    script_data bytea NULL,
    CONSTRAINT pk_house_instant_script PRIMARY KEY (char_id, slot_id)
);

CREATE TABLE houseobject (
    id integer NOT NULL,
    object_nameid integer NOT NULL,
    object_type smallint NOT NULL,
    owner_id integer NOT NULL,
    owner_type smallint NOT NULL,
    state smallint NOT NULL,
    expired_time integer DEFAULT 0 NULL,
    general_use_count integer DEFAULT 0 NULL,
    world integer DEFAULT 0 NULL,
    xlocation real DEFAULT 0.0 NULL,
    ylocation real DEFAULT 0.0 NULL,
    zlocation real DEFAULT 0.0 NULL,
    dir smallint DEFAULT 0 NULL,
    update_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    created_time timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    dye_info integer NULL,
    expire_dye_time integer NULL,
    CONSTRAINT pk_houseobject PRIMARY KEY (id)
);

CREATE TABLE houseobject_extdata (
    obj_id integer NOT NULL,
    char_id integer NOT NULL,
    accumulated_usecount integer DEFAULT 0 NOT NULL,
    next_resettime_for_owner bigint DEFAULT 0 NOT NULL,
    resource_id integer DEFAULT 0 NOT NULL,
    account_id integer DEFAULT 0 NOT NULL,
    cur_owner_usecnt_per_day smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_houseobject_extdata PRIMARY KEY (obj_id)
);

CREATE TABLE import_item_log (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    import_from_sv integer NOT NULL,
    import_from_id bigint NOT NULL,
    import_date integer NOT NULL,
    CONSTRAINT pk_import_item_log PRIMARY KEY (id)
);

CREATE TABLE instance (
    instance_id integer NOT NULL,
    validity_time integer NOT NULL,
    spawn_page integer NOT NULL,
    phase_data varchar(1024) NOT NULL
);

CREATE TABLE item_drop_ctrl (
    item_name_id integer NOT NULL,
    cur_count integer NOT NULL,
    next_reset_time bigint NOT NULL,
    CONSTRAINT pk_item_drop_ctrl PRIMARY KEY (item_name_id)
);

CREATE TABLE join_announce (
    notice_id integer NOT NULL,
    notice_subject varchar(100) NOT NULL,
    notice_pos_type smallint NOT NULL,
    notice_intro varchar(100) NULL,
    notice_etc varchar(200) NULL,
    notice_sentence_header varchar(50) NULL,
    notice_sentence1 varchar(100) NULL,
    notice_sentence2 varchar(100) NULL,
    notice_sentence3 varchar(100) NULL,
    notice_sentence4 varchar(100) NULL,
    notice_sentence5 varchar(100) NULL,
    notice_sentence6 varchar(100) NULL,
    notice_sentence7 varchar(100) NULL,
    notice_sentence8 varchar(100) NULL,
    notice_sentence9 varchar(100) NULL,
    notice_sentence10 varchar(100) NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    world_id smallint NOT NULL,
    notice_status char(1) NOT NULL,
    regdate timestamp NOT NULL,
    CONSTRAINT pk_join_announce PRIMARY KEY (notice_id)
);

CREATE TABLE legacy_log (
    id bigint NOT NULL,
    legacy_date timestamp NULL,
    legacy_count bigint NULL
);

CREATE TABLE legacy_table_list (
    id integer NOT NULL,
    log_id bigint NULL,
    table_name varchar(50) NULL,
    result integer NULL
);

CREATE TABLE legacy_user_tables (
    table_name varchar(50) NULL,
    column_name_of_charid varchar(50) NULL
);

CREATE TABLE legion_dominion_rankings (
    legion_id integer NOT NULL,
    dominion_id integer NOT NULL,
    score integer NOT NULL,
    played_time_in_sec integer NOT NULL,
    game_end_time bigint NOT NULL,
    take_over_processed_time bigint NOT NULL,
    server_id integer NOT NULL,
    CONSTRAINT pk_legion_dominion_rankings PRIMARY KEY (legion_id, take_over_processed_time, server_id)
);

CREATE TABLE npc_favor (
    char_id integer NOT NULL,
    npc_nameid integer NOT NULL,
    favor_point integer NOT NULL,
    gift_flag smallint NOT NULL
);

CREATE TABLE npc_goods_info (
    world_no integer NOT NULL,
    merchant_nameid integer NOT NULL,
    goods_list_no smallint NOT NULL,
    goods_nameid integer NOT NULL,
    sold_count bigint NOT NULL,
    CONSTRAINT pk_npc_goods_info PRIMARY KEY (world_no, merchant_nameid, goods_list_no, goods_nameid)
);

CREATE TABLE npc_limited_sales (
    id bigint NOT NULL,
    npc_id bigint NOT NULL,
    check_time bigint NULL,
    total_stock integer NULL,
    item_id bigint NULL,
    cur_stock integer NULL,
    limit_buy integer NULL,
    limit_num integer NULL,
    turn_count integer NULL,
    createtime timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    delete_flag smallint DEFAULT 0 NULL,
    CONSTRAINT pk_npc_limited_sales PRIMARY KEY (id)
);

CREATE TABLE npc_user_sales_log (
    id bigint NOT NULL,
    npc_id bigint NOT NULL,
    item_id bigint NOT NULL,
    char_id bigint NOT NULL,
    purchase_time bigint NULL,
    count bigint NULL,
    turn_count integer NULL,
    createtime timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    delete_flag smallint DEFAULT 0 NULL,
    CONSTRAINT pk_npc_user_sales_log PRIMARY KEY (id)
);

CREATE TABLE overseas_event_quest (
    quest_id integer NOT NULL
);

CREATE TABLE pk (
    pk_id integer NOT NULL,
    pk_time integer NOT NULL
);

CREATE TABLE poll_answer (
    poll_id integer NOT NULL,
    char_id integer NOT NULL,
    user_id varchar(20) NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(14) NOT NULL,
    class smallint NOT NULL,
    race smallint NOT NULL,
    world integer NOT NULL,
    xlocation real NOT NULL,
    ylocation real NOT NULL,
    zlocation real NOT NULL,
    lev smallint NOT NULL,
    answer_time timestamp NOT NULL,
    answer text NOT NULL,
    real_poll_id integer DEFAULT 0 NOT NULL,
    id integer NOT NULL,
    CONSTRAINT pk_poll_answer PRIMARY KEY (id)
);

CREATE TABLE poll_info (
    poll_id integer NOT NULL,
    status smallint NOT NULL,
    priority smallint DEFAULT 0 NOT NULL,
    start_time integer NOT NULL,
    end_time integer NOT NULL,
    race_restriction integer NOT NULL,
    class_restriction integer NOT NULL,
    level_restriction varchar(255) NOT NULL,
    world_restriction varchar(255) NOT NULL,
    reward varchar(255) NOT NULL,
    contents_size integer NOT NULL,
    contents text NOT NULL,
    abysspoint_restriction varchar(255) DEFAULT '-1/-1' NOT NULL,
    item_restriction varchar(255) DEFAULT '0' NOT NULL,
    quest_restriction varchar(255) DEFAULT '0' NOT NULL,
    region_restriction varchar(255) DEFAULT '0' NOT NULL,
    reward_item_count smallint DEFAULT 0 NOT NULL,
    poll_version smallint DEFAULT 0 NOT NULL,
    base_poll_id integer DEFAULT 0 NOT NULL,
    quest_state_restriction smallint DEFAULT 3 NOT NULL,
    quest_condition_restriction smallint DEFAULT 0 NOT NULL,
    bmaccounttype_restriction varchar(255) DEFAULT '0' NOT NULL,
    bmpacktype_restriction varchar(255) DEFAULT '0' NOT NULL,
    inter_server_type smallint DEFAULT 0 NOT NULL,
    promtion_target_restriction smallint DEFAULT 0 NOT NULL,
    game_exprience_lv_restriction smallint DEFAULT 0 NOT NULL,
    vip_grade_restriction varchar(255) DEFAULT '0' NULL,
    playtime_restriction integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_poll_info PRIMARY KEY (poll_id)
);

CREATE TABLE pvp_env (
    "type" char(1) NOT NULL,
    entity_a integer NOT NULL,
    entity_b integer NOT NULL,
    CONSTRAINT pk_pvp_env PRIMARY KEY ("type", entity_a, entity_b)
);

CREATE TABLE qina_manipulate (
    qina_id integer NOT NULL,
    accountid integer NOT NULL,
    charid integer NOT NULL,
    warehousetype integer NOT NULL,
    previousqina bigint NOT NULL,
    currentqina bigint NOT NULL,
    detectedtime timestamp NOT NULL,
    CONSTRAINT pk_qina_manipulate PRIMARY KEY (qina_id)
);

CREATE TABLE restricted_item (
    id integer NOT NULL,
    restricted_id varchar(30) NOT NULL,
    world_id smallint NOT NULL,
    service_type smallint NOT NULL,
    "type" smallint NOT NULL,
    item_name_id integer NOT NULL,
    "value" bigint NOT NULL,
    restrict_status smallint NOT NULL,
    login_id varchar(30) NOT NULL,
    login_nm varchar(30) NOT NULL,
    regdate timestamp NOT NULL,
    start_date timestamp NULL,
    end_date timestamp NULL,
    up_info varchar(1400) NULL,
    service_class_type smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_restricted_item PRIMARY KEY (id)
);

CREATE TABLE server_info (
    server_id integer NOT NULL,
    info_name varchar(255) NOT NULL,
    int_value integer DEFAULT 0 NOT NULL,
    int64_value bigint DEFAULT 0 NOT NULL,
    str_value varchar(255) NOT NULL,
    CONSTRAINT pk_server_info PRIMARY KEY (server_id, info_name)
);

CREATE TABLE spawn_area_rank (
    world_no integer NOT NULL,
    spawn_area_name varchar(40) NOT NULL,
    "rank" smallint NOT NULL
);

CREATE TABLE splog (
    "일련번호" integer NOT NULL,
    "오브젝트명" varchar(100) NULL,
    "구분" varchar(20) NULL,
    sqlcmd text NULL,
    "수정자" varchar(20) NULL,
    "수정일" timestamp NULL,
    CONSTRAINT pk_splog PRIMARY KEY ("일련번호")
);

CREATE TABLE statue_info (
    npc_name_id integer NOT NULL,
    char_id integer NOT NULL,
    CONSTRAINT pk_statue_info PRIMARY KEY (npc_name_id)
);

CREATE TABLE temp_user_copy (
    char_id integer NOT NULL,
    user_id varchar(20) NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(14) NOT NULL,
    race smallint NOT NULL,
    class smallint NOT NULL,
    is_banned boolean NOT NULL,
    gender boolean NOT NULL,
    head_face_color integer NOT NULL,
    head_hair_color integer NOT NULL,
    head_face_type smallint NOT NULL,
    head_hair_type smallint NOT NULL,
    name_id integer NOT NULL,
    guild_id integer NOT NULL,
    guild_rank smallint NOT NULL,
    guild_intro varchar(32) NOT NULL,
    guild_nickname varchar(16) NOT NULL,
    recreate_guild_time integer NOT NULL,
    org_server smallint NOT NULL,
    cur_server smallint NOT NULL,
    world integer NOT NULL,
    xlocation real NOT NULL,
    ylocation real NOT NULL,
    zlocation real NOT NULL,
    dir smallint NOT NULL,
    last_normal_world integer NOT NULL,
    last_normal_xlocation real NOT NULL,
    last_normal_ylocation real NOT NULL,
    last_normal_zlocation real NOT NULL,
    last_normal_dir smallint NOT NULL,
    death_count integer NOT NULL,
    temporary_lost_exp bigint NOT NULL,
    resurrect_world integer NOT NULL,
    resurrect_xlocation real NOT NULL,
    resurrect_ylocation real NOT NULL,
    resurrect_zlocation real NOT NULL,
    builder char(1) NOT NULL,
    now_hit integer NOT NULL,
    now_mana integer NOT NULL,
    exp bigint NOT NULL,
    abyss_point bigint NOT NULL,
    lev smallint NOT NULL,
    stigmapoint integer NOT NULL,
    event integer NOT NULL,
    create_date timestamp NOT NULL,
    petition_msg varchar(1024) NULL,
    jobfaction_id smallint NOT NULL,
    jobfaction_rank smallint NOT NULL,
    jobfaction_friendship integer NOT NULL,
    npcfaction_id smallint NOT NULL,
    npcfaction_rank smallint NOT NULL,
    cur_title_id integer NOT NULL,
    last_login_time timestamp NOT NULL,
    last_logout_time timestamp NOT NULL,
    playtime integer NOT NULL,
    fly_gauge integer NOT NULL,
    max_fly_gauge integer NOT NULL,
    fly_cool_time integer NOT NULL,
    delete_date integer NOT NULL,
    inventory_growth smallint NOT NULL,
    char_warehouse_growth smallint NOT NULL,
    daily_comment varchar(64) NOT NULL,
    head_eye_color integer NOT NULL,
    height_scale double precision NOT NULL,
    head_voice_type smallint NOT NULL,
    head_feat_type1 smallint NOT NULL,
    head_feat_type2 smallint NOT NULL,
    now_flight integer NOT NULL,
    this_week_compare_time integer NOT NULL,
    this_week_abyss_kill_cnt integer NOT NULL,
    this_week_abyss_point bigint NOT NULL,
    last_week_abyss_kill_cnt integer NOT NULL,
    last_week_abyss_point bigint NOT NULL,
    total_abyss_kill_cnt integer NOT NULL,
    best_abyss_rank integer NOT NULL,
    is_freefly smallint NOT NULL,
    feat_face_shape smallint NOT NULL,
    feat_forehead_shape smallint NOT NULL,
    feat_eye_position smallint NOT NULL,
    feat_eye_glabella smallint NOT NULL,
    feat_eye_length smallint NOT NULL,
    feat_eye_height smallint NOT NULL,
    feat_eye_shape smallint NOT NULL,
    feat_eye_tail smallint NOT NULL,
    feat_eyeblow_pos smallint NOT NULL,
    feat_eyeblow_angle smallint NOT NULL,
    feat_eyeblow_shape smallint NOT NULL,
    feat_nose_pos smallint NOT NULL,
    feat_nose_bridge smallint NOT NULL,
    feat_nose_side smallint NOT NULL,
    feat_nose_tip smallint NOT NULL,
    feat_cheek_shape smallint NOT NULL,
    feat_mouth_pos smallint NOT NULL,
    feat_mouth_size smallint NOT NULL,
    feat_lip_thickness smallint NOT NULL,
    feat_lip_tail smallint NOT NULL,
    feat_lip_shape smallint NOT NULL,
    feat_jaw_pos smallint NOT NULL,
    feat_jaw_shape smallint NOT NULL,
    feat_head_size smallint NOT NULL,
    feat_neck_thickness smallint NOT NULL,
    feat_neck_length smallint NOT NULL,
    feat_shoulder_size smallint NOT NULL,
    feat_upper_size smallint NOT NULL,
    feat_bust_size smallint NOT NULL,
    feat_waist_size smallint NOT NULL,
    feat_hip_size smallint NOT NULL,
    feat_arm_thickness smallint NOT NULL,
    feat_hand_size smallint NOT NULL,
    feat_leg_thickness smallint NOT NULL,
    feat_foot_size smallint NOT NULL,
    feat_wing_size smallint NOT NULL,
    feat_version smallint NOT NULL,
    optionflags integer NOT NULL,
    delete_complete_date integer NOT NULL,
    feat_ear_shape smallint NOT NULL,
    today_compare_time integer NOT NULL,
    today_abyss_kill_cnt integer NOT NULL,
    today_abyss_point bigint NOT NULL,
    cashitem_inventory_growth smallint NOT NULL,
    cashitem_warehouse_growth smallint NOT NULL,
    feat_face_ratio smallint NOT NULL,
    accused_count integer NOT NULL,
    last_accuse_time integer NOT NULL,
    pay_stat smallint NOT NULL,
    abyss_point_from_user bigint NOT NULL,
    guild_update_date timestamp NOT NULL,
    delete_type integer NOT NULL,
    bot_point integer NOT NULL,
    vital_point bigint NOT NULL,
    pvp_exp bigint NOT NULL,
    feat_arm_length smallint NOT NULL,
    feat_leg_length smallint NOT NULL,
    head_lip_color integer NOT NULL,
    feat_shoulder_width smallint NOT NULL,
    serial_kill_point integer NOT NULL,
    serial_kill_penalty_duration integer NOT NULL,
    serial_kill_penalty_skill_rank integer NOT NULL,
    enhanced_stigma_slot_cnt smallint NOT NULL,
    change_info_time bigint NOT NULL,
    item_legacy integer NOT NULL,
    account_punishment smallint NULL,
    head_bump_type smallint NULL,
    head_expression_type smallint NULL,
    feat_head_figure smallint NULL
);

CREATE TABLE town_data (
    town_id integer NOT NULL,
    point integer NOT NULL,
    lastlvchangedtime integer NOT NULL,
    CONSTRAINT pk_town_data PRIMARY KEY (town_id)
);

CREATE TABLE trial_account_data (
    account_id integer NOT NULL,
    reset_time integer DEFAULT 0 NOT NULL,
    sell_gold_sum bigint DEFAULT 0 NOT NULL,
    trade_gold_sum bigint DEFAULT 0 NOT NULL,
    decompose_sum integer DEFAULT 0 NOT NULL,
    gather_sum integer DEFAULT 0 NOT NULL,
    extract_gather_sum integer DEFAULT 0 NOT NULL,
    id bigint NOT NULL,
    CONSTRAINT pk_trial_account_data PRIMARY KEY (id)
);

CREATE TABLE user_abnormal_status (
    char_id integer NOT NULL,
    skill_id integer NOT NULL,
    skill_level smallint NOT NULL,
    effect_remain1 integer NOT NULL,
    effect_remain2 integer NOT NULL,
    effect_remain3 integer NOT NULL,
    effect_remain4 integer NOT NULL,
    interval_value1 integer NOT NULL,
    interval_value2 integer NOT NULL,
    interval_value3 integer NOT NULL,
    interval_value4 integer NOT NULL,
    target_slot char(1) DEFAULT 0 NOT NULL,
    logout_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_abnormal_status PRIMARY KEY (char_id, skill_id)
);

CREATE TABLE user_app_installation (
    char_id integer NOT NULL,
    can_make_sticker smallint NOT NULL,
    login_time bigint NULL,
    CONSTRAINT pk_user_app_installation PRIMARY KEY (char_id)
);

CREATE TABLE user_auction (
    id integer NOT NULL,
    "type" integer DEFAULT 1 NOT NULL,
    race integer DEFAULT 0 NOT NULL,
    goodsid integer NOT NULL,
    sellerid integer NOT NULL,
    sellername varchar(64) NOT NULL,
    buyerid integer NULL,
    buyername varchar(64) NOT NULL,
    initqina bigint DEFAULT 0 NOT NULL,
    qina bigint NOT NULL,
    stepqina bigint NOT NULL,
    state integer DEFAULT 0 NOT NULL,
    lastupdate integer NULL,
    createtime integer NULL,
    betcount integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_auction PRIMARY KEY (id)
);

CREATE TABLE user_auctionfilter (
    filterid integer NOT NULL,
    "type" integer NOT NULL,
    goodsid integer NULL,
    CONSTRAINT pk_user_auctionfilter PRIMARY KEY (filterid)
);

CREATE TABLE user_betting (
    ownerid integer NOT NULL,
    auctionid integer NOT NULL,
    qina bigint NOT NULL
);

CREATE TABLE user_bingo (
    bingo_id integer NOT NULL,
    guid integer NOT NULL,
    bingo_type smallint NOT NULL,
    bingo_nameid integer NOT NULL,
    status smallint NOT NULL,
    regdate timestamp NOT NULL,
    account_id integer NULL,
    amount smallint NULL,
    CONSTRAINT pk_user_bingo PRIMARY KEY (bingo_id)
);

CREATE TABLE user_bingo_reward (
    char_id integer NOT NULL,
    board_id integer NOT NULL,
    reward_pack_id integer NOT NULL,
    reward_date timestamp NOT NULL,
    account_id integer NULL,
    amount bigint NOT NULL,
    CONSTRAINT pk_user_bingo_reward PRIMARY KEY (board_id)
);

CREATE TABLE user_block (
    char_id integer NOT NULL,
    block_id integer NOT NULL,
    "comment" varchar(64) NOT NULL,
    CONSTRAINT pk_user_block PRIMARY KEY (char_id, block_id)
);

CREATE TABLE user_block_inter (
    char_id integer NOT NULL,
    block_id integer NOT NULL,
    "comment" varchar(64) NOT NULL,
    block_name varchar(50) DEFAULT '' NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_block_inter PRIMARY KEY (char_id, block_id, server_id)
);

CREATE TABLE user_bm_pack (
    char_id integer NOT NULL,
    pack_type smallint NOT NULL,
    pack_state smallint NOT NULL,
    expiration_time integer NOT NULL,
    unique_param integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_bm_pack PRIMARY KEY (char_id, pack_type, unique_param)
);

CREATE TABLE user_buddy_inter (
    char_id integer NOT NULL,
    buddy_id integer NOT NULL,
    delete_flag integer NOT NULL,
    buddy_name varchar(50) DEFAULT '' NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    "comment" varchar(64) NULL,
    CONSTRAINT pk_user_buddy_inter PRIMARY KEY (char_id, buddy_id, server_id)
);

CREATE TABLE user_buddy_offline (
    id integer NOT NULL,
    user_id integer NOT NULL,
    inviter_id integer NOT NULL,
    inviter_name varchar(50) NULL,
    inviter_msg varchar(256) NULL,
    createdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    userlevel integer NULL,
    userclass integer NULL,
    gender integer NULL,
    CONSTRAINT pk_user_buddy_offline PRIMARY KEY (id)
);

CREATE TABLE user_buddy1 (
    char_id integer NOT NULL,
    buddy_id integer NOT NULL,
    delete_flag smallint NOT NULL,
    "comment" varchar(64) NULL,
    CONSTRAINT pk_user_buddy1 PRIMARY KEY (char_id, buddy_id)
);

CREATE TABLE user_captcha (
    id integer NOT NULL,
    char_id integer NOT NULL,
    prohibition_flag smallint DEFAULT 0 NOT NULL,
    count smallint DEFAULT 0 NOT NULL,
    prohibition_time integer DEFAULT 0 NOT NULL,
    elapsed_time integer DEFAULT 0 NOT NULL,
    first_generation_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_captcha PRIMARY KEY (id)
);

CREATE TABLE user_change_log (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    change_type smallint NOT NULL,
    race smallint DEFAULT 0 NOT NULL,
    class smallint DEFAULT 0 NOT NULL,
    lev smallint DEFAULT 0 NOT NULL,
    old_value integer NOT NULL,
    new_value integer NOT NULL,
    change_time timestamp NOT NULL,
    playtime integer NOT NULL,
    intervaltime integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_change_log PRIMARY KEY (id)
);

CREATE TABLE user_chat_accused (
    char_id integer NOT NULL,
    accused_count integer NOT NULL,
    penalty_start_time integer NOT NULL,
    accused_count_penalty integer DEFAULT 0 NOT NULL,
    last_accused_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_chat_accused PRIMARY KEY (char_id)
);

CREATE TABLE user_client_favorite (
    char_id integer DEFAULT 0 NOT NULL,
    data_size smallint DEFAULT 0 NOT NULL,
    data bytea DEFAULT '\x00'::bytea NOT NULL,
    CONSTRAINT pk_user_client_favorite PRIMARY KEY (char_id)
);

CREATE TABLE user_client_quickbar (
    char_id integer DEFAULT 0 NOT NULL,
    data_size smallint DEFAULT 0 NOT NULL,
    data bytea DEFAULT '\x00'::bytea NOT NULL,
    CONSTRAINT pk_user_client_quickbar PRIMARY KEY (char_id)
);

CREATE TABLE user_client_settings (
    char_id integer DEFAULT 0 NOT NULL,
    data_size smallint DEFAULT 0 NOT NULL,
    data bytea DEFAULT '\x00'::bytea NOT NULL,
    CONSTRAINT pk_user_client_settings PRIMARY KEY (char_id)
);

CREATE TABLE user_combine_cooltime (
    char_id integer NOT NULL,
    cooltime_id integer NOT NULL,
    expire_cooltime bigint NOT NULL,
    CONSTRAINT pk_user_combine_cooltime PRIMARY KEY (char_id, cooltime_id)
);

CREATE TABLE user_comment (
    comment_id integer NOT NULL,
    user_id varchar(20) NOT NULL,
    char_id integer NOT NULL,
    "comment" varchar(200) NOT NULL,
    comment_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    writer varchar(64) NOT NULL,
    deleted smallint DEFAULT '0' NOT NULL,
    CONSTRAINT pk_user_comment PRIMARY KEY (comment_id)
);

CREATE TABLE user_customanimation (
    char_id integer NOT NULL,
    animation_id smallint NOT NULL,
    animation_type smallint NOT NULL,
    usestate smallint DEFAULT 0 NOT NULL,
    expire_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_customanimation PRIMARY KEY (char_id, animation_id)
);

CREATE TABLE user_customize_history (
    id integer NOT NULL,
    char_id integer NOT NULL,
    user_id varchar(20) DEFAULT '' NOT NULL,
    account_id integer DEFAULT 0 NOT NULL,
    account_name varchar(14) DEFAULT '' NOT NULL,
    race smallint NOT NULL,
    class smallint NOT NULL,
    gender boolean NOT NULL,
    lev smallint NOT NULL,
    history_date timestamp NOT NULL,
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
    feat_version smallint DEFAULT 0 NOT NULL,
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
    feat_ear_shape smallint DEFAULT 0 NOT NULL,
    feat_face_ratio smallint DEFAULT 0 NOT NULL,
    feat_wing_size smallint DEFAULT 0 NOT NULL,
    feat_arm_length smallint DEFAULT 1 NOT NULL,
    feat_leg_length smallint DEFAULT 1 NOT NULL,
    feat_shoulder_width smallint DEFAULT 1 NOT NULL,
    head_bump_type smallint NULL,
    head_expression_type smallint NULL,
    feat_head_figure smallint NULL,
    head_eye_type smallint NULL,
    head_dark_tail smallint NULL,
    head_eye_color2 integer NULL,
    head_eye_lash smallint NULL,
    feat_head_eye_size smallint NULL,
    feat_upper_height smallint NULL,
    feat_arm_lower_thickness smallint NULL,
    feat_hand_length smallint NULL,
    feat_leg_lower_thickness smallint NULL,
    CONSTRAINT pk_user_customize_history PRIMARY KEY (id)
);

CREATE TABLE user_data (
    char_id integer NOT NULL,
    user_id varchar(20) NOT NULL,
    account_id integer NOT NULL,
    account_name varchar(14) DEFAULT '' NOT NULL,
    race smallint NOT NULL,
    class smallint NOT NULL,
    is_banned boolean NOT NULL,
    gender boolean NOT NULL,
    head_face_color integer NOT NULL,
    head_hair_color integer NOT NULL,
    head_face_type smallint NOT NULL,
    head_hair_type smallint NOT NULL,
    name_id integer NOT NULL,
    guild_id integer NOT NULL,
    guild_rank smallint DEFAULT 0 NOT NULL,
    guild_intro varchar(32) DEFAULT '' NOT NULL,
    guild_nickname varchar(16) DEFAULT '' NOT NULL,
    recreate_guild_time integer DEFAULT 0 NOT NULL,
    org_server smallint DEFAULT 0 NOT NULL,
    cur_server smallint DEFAULT 0 NOT NULL,
    world integer NOT NULL,
    xlocation real NOT NULL,
    ylocation real NOT NULL,
    zlocation real NOT NULL,
    dir smallint NOT NULL,
    last_normal_world integer DEFAULT 0 NOT NULL,
    last_normal_xlocation real DEFAULT 0 NOT NULL,
    last_normal_ylocation real DEFAULT 0 NOT NULL,
    last_normal_zlocation real DEFAULT 0 NOT NULL,
    last_normal_dir smallint DEFAULT 0 NOT NULL,
    death_count integer DEFAULT 0 NOT NULL,
    temporary_lost_exp bigint DEFAULT 0 NOT NULL,
    resurrect_world integer DEFAULT 0 NOT NULL,
    resurrect_xlocation real DEFAULT 0 NOT NULL,
    resurrect_ylocation real DEFAULT 0 NOT NULL,
    resurrect_zlocation real DEFAULT 0 NOT NULL,
    builder char(1) NOT NULL,
    now_hit integer NOT NULL,
    now_mana integer NOT NULL,
    exp bigint NOT NULL,
    abyss_point bigint DEFAULT 0 NOT NULL,
    lev smallint NOT NULL,
    stigmapoint integer NOT NULL,
    event integer NOT NULL,
    create_date timestamp NOT NULL,
    petition_msg varchar(1024) NULL,
    jobfaction_id smallint DEFAULT 0 NOT NULL,
    jobfaction_rank smallint DEFAULT 0 NOT NULL,
    jobfaction_friendship integer DEFAULT 0 NOT NULL,
    npcfaction_id smallint DEFAULT 0 NOT NULL,
    npcfaction_rank smallint DEFAULT 0 NOT NULL,
    cur_title_id integer DEFAULT 0 NOT NULL,
    last_login_time timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_logout_time timestamp DEFAULT '1970-1-1 0:0:1'::timestamp NOT NULL,
    playtime integer DEFAULT 0 NOT NULL,
    fly_gauge integer DEFAULT 0 NOT NULL,
    max_fly_gauge integer DEFAULT 0 NOT NULL,
    fly_cool_time integer DEFAULT 0 NOT NULL,
    delete_date integer DEFAULT 0 NOT NULL,
    inventory_growth smallint DEFAULT 0 NOT NULL,
    char_warehouse_growth smallint DEFAULT 0 NOT NULL,
    daily_comment varchar(64) NOT NULL,
    head_eye_color integer DEFAULT 0xFFFFFFFF NOT NULL,
    height_scale double precision DEFAULT 1.0 NOT NULL,
    head_voice_type smallint DEFAULT 0 NOT NULL,
    head_feat_type1 smallint DEFAULT 0 NOT NULL,
    head_feat_type2 smallint DEFAULT 0 NOT NULL,
    now_flight integer DEFAULT 0 NOT NULL,
    this_week_compare_time integer DEFAULT 0 NOT NULL,
    this_week_abyss_kill_cnt integer DEFAULT 0 NOT NULL,
    this_week_abyss_point bigint DEFAULT 0 NOT NULL,
    last_week_abyss_kill_cnt integer DEFAULT 0 NOT NULL,
    last_week_abyss_point bigint DEFAULT 0 NOT NULL,
    total_abyss_kill_cnt integer DEFAULT 0 NOT NULL,
    best_abyss_rank integer DEFAULT 0 NOT NULL,
    is_freefly smallint DEFAULT 0 NOT NULL,
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
    feat_version smallint DEFAULT 0 NOT NULL,
    optionflags integer DEFAULT 0 NOT NULL,
    delete_complete_date integer DEFAULT 0 NOT NULL,
    feat_ear_shape smallint DEFAULT 0 NOT NULL,
    today_compare_time integer DEFAULT 0 NOT NULL,
    today_abyss_kill_cnt integer DEFAULT 0 NOT NULL,
    today_abyss_point bigint DEFAULT 0 NOT NULL,
    cashitem_inventory_growth smallint DEFAULT 0 NOT NULL,
    cashitem_warehouse_growth smallint DEFAULT 0 NOT NULL,
    feat_face_ratio smallint DEFAULT 0 NOT NULL,
    accused_count integer DEFAULT 0 NOT NULL,
    last_accuse_time integer DEFAULT 0 NOT NULL,
    pay_stat smallint DEFAULT 0 NOT NULL,
    abyss_point_from_user bigint DEFAULT 0 NOT NULL,
    guild_update_date timestamp DEFAULT '1970-01-01 00:00:00'::timestamp NOT NULL,
    delete_type integer DEFAULT 0 NOT NULL,
    bot_point integer DEFAULT 0 NOT NULL,
    vital_point bigint DEFAULT 0 NOT NULL,
    pvp_exp bigint DEFAULT 0 NOT NULL,
    feat_arm_length smallint DEFAULT 1 NOT NULL,
    feat_leg_length smallint DEFAULT 1 NOT NULL,
    head_lip_color integer DEFAULT 0 NOT NULL,
    feat_shoulder_width smallint DEFAULT 1 NOT NULL,
    serial_kill_point integer DEFAULT 0 NOT NULL,
    serial_kill_penalty_duration integer DEFAULT 0 NOT NULL,
    serial_kill_penalty_skill_rank integer DEFAULT 0 NOT NULL,
    change_info_time bigint DEFAULT 0 NOT NULL,
    enhanced_stigma_slot_cnt smallint DEFAULT 0 NOT NULL,
    account_punishment smallint NULL,
    item_legacy integer DEFAULT 0 NOT NULL,
    head_bump_type smallint NULL,
    head_expression_type smallint NULL,
    feat_head_figure smallint NULL,
    login_server integer DEFAULT 0 NULL,
    housing_id integer DEFAULT 0 NOT NULL,
    cur_title_attr_id integer DEFAULT 0 NOT NULL,
    world_map_number integer DEFAULT 0 NOT NULL,
    today_glory_point integer DEFAULT '0' NOT NULL,
    this_week_glory_point integer DEFAULT '0' NOT NULL,
    last_week_glory_point integer DEFAULT '0' NOT NULL,
    fatigue_resttime_online integer DEFAULT 0 NOT NULL,
    next_hotspot_use_time bigint DEFAULT 0 NOT NULL,
    last_explicit_beginner_force smallint DEFAULT 0 NOT NULL,
    gotcha_fever_point integer DEFAULT 0 NOT NULL,
    gotcha_fever_expire_time bigint DEFAULT 0 NOT NULL,
    absolute_exp bigint DEFAULT 0 NOT NULL,
    serial_guard_point integer DEFAULT 0 NOT NULL,
    serial_guard_last_scantime integer DEFAULT 0 NOT NULL,
    guild_offline_change_flag smallint DEFAULT 0 NOT NULL,
    gotcha_fever_hit_count integer DEFAULT 0 NOT NULL,
    head_eye_type smallint NULL,
    head_dark_tail smallint NULL,
    head_eye_color2 integer NULL,
    head_eye_lash smallint NULL,
    feat_head_eye_size smallint NULL,
    feat_upper_height smallint NULL,
    feat_arm_lower_thickness smallint NULL,
    feat_hand_length smallint NULL,
    feat_leg_lower_thickness smallint NULL,
    is_jumping_character smallint DEFAULT 0 NOT NULL,
    two_weeks_ago_glory_point integer DEFAULT 0 NOT NULL,
    three_weeks_ago_glory_point integer DEFAULT 0 NOT NULL,
    absolute_ap bigint DEFAULT 0 NOT NULL,
    hardware varchar(16) NULL,
    CONSTRAINT pk_user_data PRIMARY KEY (char_id)
);

CREATE TABLE user_data_ext (
    char_id integer NOT NULL,
    exps_login_reward_time integer DEFAULT 0 NOT NULL,
    exps_npckill_reward_num integer DEFAULT 0 NOT NULL,
    creativity_point integer DEFAULT 0 NOT NULL,
    usecp_resetcount smallint DEFAULT 0 NOT NULL,
    next_usecp_resetcount_dec_time bigint DEFAULT 0 NOT NULL,
    global_tnmt_apply_seq integer DEFAULT 0 NOT NULL,
    local_tnmt_apply_seq integer DEFAULT 0 NOT NULL,
    familiar_func_expiretime bigint DEFAULT 0 NOT NULL,
    familiar_energy integer DEFAULT 0 NOT NULL,
    familiar_energy_autocharge smallint DEFAULT 0 NOT NULL,
    familiar_func_autocharge smallint DEFAULT 0 NOT NULL,
    last_transform_id integer DEFAULT 0 NOT NULL,
    last_transform_scroll_id integer DEFAULT 0 NOT NULL,
    last_summon_familiar integer DEFAULT 0 NOT NULL,
    last_collection_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_data_ext PRIMARY KEY (char_id)
);

CREATE TABLE user_disassembly_retry (
    charid integer DEFAULT 0 NOT NULL,
    itemid bigint DEFAULT 0 NOT NULL,
    retrycount integer DEFAULT 0 NOT NULL,
    isdelete smallint DEFAULT 0 NOT NULL,
    nameid1 integer DEFAULT 0 NOT NULL,
    itemcount1 integer DEFAULT 0 NOT NULL,
    nameid2 integer DEFAULT 0 NOT NULL,
    itemcount2 integer DEFAULT 0 NOT NULL,
    nameid3 integer DEFAULT 0 NOT NULL,
    itemcount3 integer DEFAULT 0 NOT NULL,
    nameid4 integer DEFAULT 0 NOT NULL,
    itemcount4 integer DEFAULT 0 NOT NULL,
    nameid5 integer DEFAULT 0 NOT NULL,
    itemcount5 integer DEFAULT 0 NOT NULL,
    updatedate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_user_disassembly_retry PRIMARY KEY (itemid)
);

CREATE TABLE user_dportal (
    char_id integer NOT NULL,
    dpid integer NOT NULL,
    lastdp_world integer DEFAULT 0 NOT NULL,
    lastdp_xlocation real DEFAULT 0 NOT NULL,
    lastdp_ylocation real DEFAULT 0 NOT NULL,
    lastdp_zlocation real DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_dportal PRIMARY KEY (char_id)
);

CREATE TABLE user_emotion (
    char_id integer NOT NULL,
    emotion_type smallint NOT NULL,
    expire_date integer NOT NULL,
    CONSTRAINT pk_user_emotion PRIMARY KEY (char_id, emotion_type)
);

CREATE TABLE user_equipment_change_flag (
    char_id integer NOT NULL,
    set_id smallint NOT NULL,
    option_flags integer NOT NULL
);

CREATE TABLE user_equipment_change_item (
    char_id integer NOT NULL,
    set_id smallint NOT NULL,
    eqslot smallint NOT NULL,
    item_id bigint NOT NULL
);

CREATE TABLE user_escrow (
    id integer NOT NULL,
    seller integer NOT NULL,
    qina bigint DEFAULT 0 NOT NULL,
    itemid bigint DEFAULT 0 NOT NULL,
    itemamount bigint DEFAULT 0 NOT NULL,
    buyer integer DEFAULT 0 NOT NULL,
    state integer DEFAULT 0 NOT NULL,
    registerdate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completedate timestamp NULL,
    CONSTRAINT pk_user_escrow PRIMARY KEY (id)
);

CREATE TABLE user_extra_info (
    char_id integer NOT NULL,
    use_bot_channel smallint NOT NULL,
    use_bot_channel_update_date timestamp NULL,
    account_id integer NULL,
    vip_icon smallint DEFAULT 0 NULL,
    prevseasonreward integer NULL,
    currentseasonreward integer NULL,
    CONSTRAINT pk_user_extra_info PRIMARY KEY (char_id)
);

CREATE TABLE user_faction_friendship (
    char_id integer NOT NULL,
    faction_id smallint NOT NULL,
    friendship integer NOT NULL,
    jointime integer DEFAULT 0 NOT NULL,
    factionquest_curid integer DEFAULT 0 NULL,
    factionquest_curstate integer DEFAULT 0 NULL,
    factionquest_lastacquiredtime integer DEFAULT 0 NULL,
    factionquest_lastfinishedtime integer DEFAULT 0 NULL,
    factionquest_finishedcount integer DEFAULT 0 NULL,
    CONSTRAINT pk_user_faction_friendship PRIMARY KEY (char_id, faction_id)
);

CREATE TABLE user_familiar (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    base_name_id integer NOT NULL,
    cur_name_id integer NOT NULL,
    "name" varchar(50) NOT NULL,
    evolve_cnt integer NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    safety_flag smallint NOT NULL,
    growth_point integer NOT NULL,
    slot1 integer NOT NULL,
    slot2 integer NOT NULL,
    slot3 integer NOT NULL,
    slot4 integer NOT NULL,
    slot5 integer NOT NULL,
    slot6 integer NOT NULL,
    looting_state smallint NOT NULL,
    deleted smallint NOT NULL,
    CONSTRAINT pk_user_familiar PRIMARY KEY (id)
);

CREATE TABLE user_finished_quest (
    char_id integer NOT NULL,
    quest_id integer NOT NULL,
    quest_count integer DEFAULT 1 NOT NULL,
    quest_branch char(1) DEFAULT 0 NOT NULL,
    quest_finishedtime integer DEFAULT 0 NULL,
    repeat_quest_count integer DEFAULT 1 NOT NULL,
    repeat_quest_resetnum integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_finished_quest PRIMARY KEY (char_id, quest_id)
);

CREATE TABLE user_gather_cooltime (
    char_id integer NOT NULL,
    cooltime_id integer NOT NULL,
    expire_cooltime bigint NOT NULL,
    CONSTRAINT pk_user_gather_cooltime PRIMARY KEY (char_id, cooltime_id)
);

CREATE TABLE user_gp_data (
    char_id integer NOT NULL,
    glory_point integer NOT NULL,
    ownership_bonus_gp integer DEFAULT '0' NOT NULL,
    CONSTRAINT pk_user_gp_data PRIMARY KEY (char_id)
);

CREATE TABLE user_grace (
    grace_id integer NOT NULL,
    owner_id integer NOT NULL,
    goods_id integer NOT NULL,
    building_id integer NOT NULL,
    starttime integer NOT NULL,
    state integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_grace PRIMARY KEY (grace_id)
);

CREATE TABLE user_guild_join_application (
    char_id integer NOT NULL,
    guild_id integer NOT NULL,
    applicant_intro varchar(32) DEFAULT '' NOT NULL,
    apply_time integer NOT NULL,
    CONSTRAINT pk_user_guild_join_application PRIMARY KEY (char_id)
);

CREATE TABLE user_instance (
    id integer NOT NULL,
    char_id integer NOT NULL,
    world_id integer NOT NULL,
    instance_id integer NOT NULL,
    reentrance_time integer DEFAULT 0 NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    count_variate integer DEFAULT 0 NOT NULL,
    kina_increase integer DEFAULT 0 NOT NULL,
    item_increase integer DEFAULT 0 NOT NULL,
    spinel_increase integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_instance PRIMARY KEY (id)
);

CREATE TABLE user_instance_achievement (
    id integer NOT NULL,
    char_id integer DEFAULT 0 NOT NULL,
    world_id integer DEFAULT 0 NOT NULL,
    spawn_page integer DEFAULT 0 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    data bytea NULL,
    CONSTRAINT pk_user_instance_achievement PRIMARY KEY (id)
);

CREATE TABLE user_instance_extracount (
    char_id integer NOT NULL,
    map_number integer NOT NULL,
    extra_count_abyssop smallint NOT NULL,
    next_reset_time bigint NOT NULL,
    CONSTRAINT pk_user_instance_extracount PRIMARY KEY (char_id, map_number)
);

CREATE TABLE user_item (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    name_id integer NOT NULL,
    slot_id smallint DEFAULT -1 NOT NULL,
    amount bigint NOT NULL,
    slot smallint NOT NULL,
    warehouse smallint NOT NULL,
    create_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    producer varchar(20) DEFAULT '' NOT NULL,
    tid bigint DEFAULT 0 NOT NULL,
    expired_time integer DEFAULT 0 NOT NULL,
    buy_amount smallint DEFAULT 0 NOT NULL,
    buy_duration smallint DEFAULT 0 NOT NULL,
    main_item_dbid bigint DEFAULT 0 NOT NULL,
    dynamic_property integer DEFAULT 0 NOT NULL,
    import_id bigint DEFAULT 0 NOT NULL,
    export_id bigint DEFAULT 0 NOT NULL,
    server_of_origin smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_item PRIMARY KEY (id)
);

CREATE TABLE user_item_attribute (
    id bigint NOT NULL,
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
    CONSTRAINT pk_user_item_attribute PRIMARY KEY (id)
);

CREATE TABLE user_item_bind (
    item_id bigint NOT NULL,
    actor_type integer DEFAULT 0 NOT NULL,
    actor_value integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_item_bind PRIMARY KEY (item_id)
);

CREATE TABLE user_item_charge (
    id bigint NOT NULL,
    charge_point integer NOT NULL,
    CONSTRAINT pk_user_item_charge PRIMARY KEY (id)
);

CREATE TABLE user_item_cooltime (
    char_id integer NOT NULL,
    cooltime_data_cnt smallint NOT NULL,
    data bytea NOT NULL,
    CONSTRAINT pk_user_item_cooltime PRIMARY KEY (char_id)
);

CREATE TABLE user_item_enslave_stone (
    id bigint NOT NULL,
    status smallint NOT NULL,
    monsterclass integer NOT NULL,
    lev smallint NOT NULL,
    exp bigint NOT NULL,
    CONSTRAINT pk_user_item_enslave_stone PRIMARY KEY (id)
);

CREATE TABLE user_item_ext (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    sa_custom1 integer NOT NULL,
    CONSTRAINT pk_user_item_ext PRIMARY KEY (id)
);

CREATE TABLE user_item_freetrade (
    id bigint NOT NULL,
    name_id integer NULL,
    freetradestate integer NULL,
    CONSTRAINT pk_user_item_freetrade PRIMARY KEY (id)
);

CREATE TABLE user_item_merge (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    name_id integer NOT NULL,
    slot_id smallint NOT NULL,
    amount bigint NOT NULL,
    slot smallint NOT NULL,
    warehouse smallint NOT NULL,
    soul_bound smallint NOT NULL,
    enchant_count smallint NOT NULL,
    skin_name_id integer NOT NULL,
    stat_enchant_0 smallint NOT NULL,
    stat_enchant_val0 smallint NOT NULL,
    stat_enchant_name0 integer NOT NULL,
    stat_enchant_1 smallint NOT NULL,
    stat_enchant_val1 smallint NOT NULL,
    stat_enchant_name1 integer NOT NULL,
    stat_enchant_2 smallint NOT NULL,
    stat_enchant_val2 smallint NOT NULL,
    stat_enchant_name2 integer NOT NULL,
    stat_enchant_3 smallint NOT NULL,
    stat_enchant_val3 smallint NOT NULL,
    stat_enchant_name3 integer NOT NULL,
    dye_info integer NOT NULL,
    proc_tool_nameid integer NOT NULL,
    create_date timestamp NOT NULL,
    update_date timestamp NOT NULL,
    producer varchar(20) NOT NULL,
    tid bigint NOT NULL,
    expired_time integer NOT NULL,
    stat_enchant_4 smallint NOT NULL,
    stat_enchant_val4 smallint NOT NULL,
    stat_enchant_name4 integer NOT NULL,
    stat_enchant_5 smallint NOT NULL,
    stat_enchant_val5 smallint NOT NULL,
    stat_enchant_name5 integer NOT NULL,
    option_count smallint NOT NULL,
    buy_amount smallint NOT NULL,
    buy_duration smallint NOT NULL,
    obtain_skin_type smallint NOT NULL,
    expire_skin_time integer NOT NULL,
    main_item_dbid bigint NOT NULL,
    dynamic_property integer NOT NULL,
    expire_dye_time integer NOT NULL,
    import_id bigint NOT NULL,
    export_id bigint NOT NULL,
    server_of_origin smallint NOT NULL,
    random_option smallint NOT NULL,
    authorize_count smallint NOT NULL,
    exceedstate smallint NOT NULL,
    exceedskillid1 integer NOT NULL,
    exceedskillid2 integer NOT NULL,
    exceedskillid3 integer NOT NULL
);

CREATE TABLE user_item_option (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    soul_bound smallint DEFAULT 0 NULL,
    enchant_count smallint DEFAULT 0 NULL,
    skin_name_id integer DEFAULT 0 NULL,
    stat_enchant_name0 integer DEFAULT 0 NULL,
    stat_enchant_0 smallint DEFAULT 0 NULL,
    stat_enchant_val0 smallint DEFAULT 0 NULL,
    stat_enchant_name1 integer DEFAULT 0 NULL,
    stat_enchant_1 smallint DEFAULT 0 NULL,
    stat_enchant_val1 smallint DEFAULT 0 NULL,
    stat_enchant_name2 integer DEFAULT 0 NULL,
    stat_enchant_2 smallint DEFAULT 0 NULL,
    stat_enchant_val2 smallint DEFAULT 0 NULL,
    stat_enchant_name3 integer DEFAULT 0 NULL,
    stat_enchant_3 smallint DEFAULT 0 NULL,
    stat_enchant_val3 smallint DEFAULT 0 NULL,
    stat_enchant_name4 integer DEFAULT 0 NULL,
    stat_enchant_4 smallint DEFAULT 0 NULL,
    stat_enchant_val4 smallint DEFAULT 0 NULL,
    stat_enchant_name5 integer DEFAULT 0 NULL,
    stat_enchant_5 smallint DEFAULT 0 NULL,
    stat_enchant_val5 smallint DEFAULT 0 NULL,
    option_count smallint DEFAULT 0 NULL,
    dye_info integer DEFAULT 0 NULL,
    proc_tool_nameid integer DEFAULT 0 NULL,
    obtain_skin_type smallint DEFAULT 0 NULL,
    expire_skin_time integer DEFAULT 0 NULL,
    expire_dye_time integer DEFAULT 0 NULL,
    random_option smallint DEFAULT 0 NULL,
    limit_enchant_count smallint NULL,
    reidentify_count smallint DEFAULT 0 NULL,
    authorize_count smallint DEFAULT 0 NULL,
    vanish_point integer DEFAULT 0 NULL,
    enchant_prob_addition integer NULL,
    option_prob_addition integer NULL,
    proc_break_count integer NULL,
    proc_break_flag smallint NULL,
    keynameid integer DEFAULT 0 NOT NULL,
    exceedstate smallint DEFAULT 0 NOT NULL,
    exceedskillid1 integer DEFAULT 0 NOT NULL,
    exceedskillid2 integer DEFAULT 0 NOT NULL,
    exceedskillid3 integer DEFAULT 0 NOT NULL,
    baseskillid integer DEFAULT 0 NOT NULL,
    enhanceskillgroup integer DEFAULT 0 NOT NULL,
    enhanceskilllevel integer DEFAULT 0 NOT NULL,
    equipleveldown smallint NULL,
    wardrobeslotid smallint DEFAULT 0 NOT NULL,
    randomattr1 integer NULL,
    randomvalue1 integer NULL,
    randomattr2 integer NULL,
    randomvalue2 integer NULL,
    randomattr3 integer NULL,
    randomvalue3 integer NULL,
    randomattr4 integer NULL,
    randomvalue4 integer NULL,
    randomattr5 integer NULL,
    randomvalue5 integer NULL,
    randomattr6 integer NULL,
    randomvalue6 integer NULL,
    randomattr7 integer NULL,
    randomvalue7 integer NULL,
    randomattr8 integer NULL,
    randomvalue8 integer NULL,
    randomattr9 integer NULL,
    randomvalue9 integer NULL,
    randomattr10 integer NULL,
    randomvalue10 integer NULL,
    skill_skin_name_id integer DEFAULT 0 NULL,
    CONSTRAINT pk_user_item_option PRIMARY KEY (id)
);

CREATE TABLE user_item_polish (
    id bigint NOT NULL,
    name_id integer NOT NULL,
    random_id integer NOT NULL,
    polish_point integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_item_polish PRIMARY KEY (id)
);

CREATE TABLE user_item_sealed (
    id bigint NOT NULL,
    sealexpiredtime integer DEFAULT 0 NOT NULL,
    sealstate smallint DEFAULT 0 NOT NULL,
    char_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_item_sealed PRIMARY KEY (id)
);

CREATE TABLE user_item_signature (
    char_id integer NOT NULL,
    signature bigint NOT NULL
);

CREATE TABLE user_luna_abyss_boost (
    char_id integer NOT NULL,
    abyss_id integer NOT NULL,
    is_boost_on smallint NOT NULL,
    CONSTRAINT pk_user_luna_abyss_boost PRIMARY KEY (char_id, abyss_id)
);

CREATE TABLE user_luna_dice_gotcha (
    char_id integer NOT NULL,
    open_num integer NOT NULL,
    use_special_dice smallint NOT NULL,
    recv_reward_time bigint NOT NULL,
    CONSTRAINT pk_user_luna_dice_gotcha PRIMARY KEY (char_id)
);

CREATE TABLE user_luna_price (
    char_id integer NOT NULL,
    luna_id integer DEFAULT 0 NOT NULL,
    use_count integer DEFAULT 0 NOT NULL,
    reset_type smallint NULL,
    reset_week_value smallint NULL,
    reset_time_value integer NULL,
    create_time bigint DEFAULT 0 NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    CONSTRAINT pk_user_luna_price PRIMARY KEY (char_id, luna_id)
);

CREATE TABLE user_macro (
    char_id integer NOT NULL,
    slot_id smallint NOT NULL,
    data char(1024) NULL,
    CONSTRAINT pk_user_macro PRIMARY KEY (char_id, slot_id)
);

CREATE TABLE user_mail (
    id integer NOT NULL,
    to_id integer NOT NULL,
    to_name varchar(20) NOT NULL,
    from_id integer NOT NULL,
    from_name varchar(20) NULL,
    title varchar(20) NOT NULL,
    content varchar(1000) NULL,
    item_id bigint DEFAULT 0 NOT NULL,
    item_nameid integer NOT NULL,
    item_amount bigint NOT NULL,
    money bigint DEFAULT 0 NOT NULL,
    state smallint DEFAULT 0 NOT NULL,
    arrive_time integer NOT NULL,
    express_mail smallint DEFAULT 0 NOT NULL,
    item_tid bigint DEFAULT 0 NOT NULL,
    abyss_point bigint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_mail PRIMARY KEY (id)
);

CREATE TABLE user_monster_achievement (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    achieve_id integer NOT NULL,
    achieved_count integer NOT NULL,
    achieved_grade smallint NOT NULL,
    reward_received smallint NOT NULL,
    CONSTRAINT pk_user_monster_achievement PRIMARY KEY (id)
);

CREATE TABLE user_move_service_log (
    id integer NOT NULL,
    char_id integer NOT NULL,
    char_id_delete integer NOT NULL,
    server_id_from integer NOT NULL,
    char_id_from integer NOT NULL,
    user_id_from varchar(20) NOT NULL,
    move_date timestamp NOT NULL,
    account_id integer DEFAULT 0 NOT NULL,
    account_name varchar(14) DEFAULT '' NOT NULL,
    race smallint DEFAULT 0 NOT NULL,
    class smallint DEFAULT 0 NOT NULL,
    gender boolean DEFAULT false NOT NULL,
    lev smallint DEFAULT 0 NOT NULL,
    warehouse integer DEFAULT 0 NOT NULL,
    premium integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_move_service_log PRIMARY KEY (id)
);

CREATE TABLE user_name_change_log (
    id integer NOT NULL,
    char_id integer NOT NULL,
    old_name varchar(20) NOT NULL,
    new_name varchar(20) NOT NULL,
    change_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    item_id bigint NOT NULL,
    tid bigint DEFAULT 0 NOT NULL,
    account_id integer DEFAULT 0 NOT NULL,
    account_name varchar(14) DEFAULT '' NOT NULL,
    race smallint DEFAULT 0 NOT NULL,
    class smallint DEFAULT 0 NOT NULL,
    gender boolean DEFAULT false NOT NULL,
    lev smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_name_change_log PRIMARY KEY (id)
);

CREATE TABLE user_old_character (
    char_id integer NOT NULL,
    old_char_id integer NOT NULL,
    old_server_id integer NOT NULL,
    old_char_name varchar(50) NOT NULL,
    delete_flag smallint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_old_character PRIMARY KEY (char_id)
);

CREATE TABLE user_pet (
    id bigint NOT NULL,
    char_id integer DEFAULT 0 NOT NULL,
    name_id integer DEFAULT 0 NOT NULL,
    slot_id smallint DEFAULT 0 NOT NULL,
    "name" varchar(20) NOT NULL,
    function_data1 bigint DEFAULT 0 NOT NULL,
    function_data2 bigint DEFAULT 0 NOT NULL,
    create_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    visual_data_size integer DEFAULT 0 NOT NULL,
    visual_data bytea NULL,
    change_info_time bigint DEFAULT 0 NOT NULL,
    function_data1_ex1 bigint DEFAULT 0 NOT NULL,
    function_data1_ex2 bigint DEFAULT 0 NOT NULL,
    function_data1_ex3 bigint DEFAULT 0 NOT NULL,
    function_data2_ex1 bigint DEFAULT 0 NOT NULL,
    function_data2_ex2 bigint DEFAULT 0 NOT NULL,
    function_data2_ex3 bigint DEFAULT 0 NOT NULL,
    expired_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_pet PRIMARY KEY (id)
);

CREATE TABLE user_petition_msg (
    id integer NOT NULL,
    char_id integer NOT NULL,
    petition_sv_id integer NOT NULL,
    msg varchar(1024) NOT NULL,
    CONSTRAINT pk_user_petition_msg PRIMARY KEY (id)
);

CREATE TABLE user_petition_web (
    id integer NOT NULL,
    char_id integer NOT NULL
);

CREATE TABLE user_promotion_cooltime (
    char_id integer NOT NULL,
    promotion_id integer NOT NULL,
    last_promotion_time integer NOT NULL,
    received_item_count integer DEFAULT 0 NOT NULL,
    cycle_received_item_count integer DEFAULT 0 NOT NULL,
    cycle_next_reset_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_promotion_cooltime PRIMARY KEY (char_id, promotion_id)
);

CREATE TABLE user_punishment (
    id integer NOT NULL,
    account_id integer NOT NULL,
    char_id integer NOT NULL,
    play_block smallint NOT NULL,
    status smallint NOT NULL,
    punish_code integer NOT NULL,
    start_date timestamp NOT NULL,
    end_date timestamp NOT NULL,
    remain_minute integer DEFAULT 0 NOT NULL,
    cancel_date timestamp NULL,
    cancel_reason varchar(200) NULL,
    punish_reason varchar(200) NOT NULL,
    login_id varchar(30) NULL,
    login_nm varchar(30) NULL,
    CONSTRAINT pk_user_punishment PRIMARY KEY (id)
);

CREATE TABLE user_punishmentnew (
    account_id integer NOT NULL,
    char_id integer NOT NULL,
    play_block smallint NOT NULL,
    status smallint NOT NULL,
    punish_code integer NOT NULL,
    start_date timestamp NOT NULL,
    end_date timestamp NOT NULL,
    remain_minute integer NOT NULL,
    cancel_date timestamp NULL,
    cancel_reason varchar(200) NULL,
    punish_reason varchar(200) NOT NULL,
    login_id varchar(30) NULL,
    login_nm varchar(30) NULL
);

CREATE TABLE user_quest (
    char_id integer NOT NULL,
    quest_id integer NOT NULL,
    quest_status smallint NOT NULL,
    quest_progress integer DEFAULT 0 NOT NULL,
    quest_branch char(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_quest PRIMARY KEY (char_id, quest_id)
);

CREATE TABLE user_rank (
    id integer NOT NULL,
    char_id integer NOT NULL,
    rank_id integer NOT NULL,
    point integer NOT NULL,
    global_ranking integer DEFAULT 0 NOT NULL,
    global_old_ranking integer DEFAULT 0 NOT NULL,
    local_ranking integer DEFAULT 0 NOT NULL,
    local_old_ranking integer DEFAULT 0 NOT NULL,
    last_ranking integer DEFAULT 0 NOT NULL,
    last_point integer DEFAULT -2147483648 NOT NULL,
    best_ranking integer DEFAULT 0 NOT NULL,
    best_point integer DEFAULT -2147483648 NOT NULL,
    CONSTRAINT pk_user_rank PRIMARY KEY (id)
);

CREATE TABLE user_rank_update_time (
    rank_id integer NOT NULL,
    daily_update_time bigint DEFAULT 0 NOT NULL,
    season_update_time bigint DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_rank_update_time PRIMARY KEY (rank_id)
);

CREATE TABLE user_rate (
    id integer NOT NULL,
    char_id integer NOT NULL,
    rate_id integer NOT NULL,
    mu double precision NOT NULL,
    sigma double precision NOT NULL,
    update_cnt integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_rate PRIMARY KEY (id)
);

CREATE TABLE user_recipe (
    char_id integer NOT NULL,
    recipe_id integer NOT NULL,
    remain_count smallint DEFAULT '0' NOT NULL,
    CONSTRAINT pk_user_recipe PRIMARY KEY (char_id, recipe_id)
);

CREATE TABLE user_recovery_info (
    char_id integer NOT NULL,
    recovery_status smallint NOT NULL,
    CONSTRAINT pk_user_recovery_info PRIMARY KEY (char_id)
);

CREATE TABLE user_reform (
    char_id integer NOT NULL,
    next_reset_time integer NOT NULL,
    reform_count integer NOT NULL
);

CREATE TABLE user_server_transfer (
    idx integer NOT NULL,
    char_id integer NOT NULL,
    user_state integer NOT NULL,
    reg_service_id integer NOT NULL,
    CONSTRAINT pk_user_server_transfer PRIMARY KEY (idx)
);

CREATE TABLE user_skill (
    char_id integer NOT NULL,
    skill_id integer NOT NULL,
    skill_data1 integer NOT NULL,
    skill_data2 integer NOT NULL,
    CONSTRAINT pk_user_skill PRIMARY KEY (char_id, skill_id)
);

CREATE TABLE user_skill_backup (
    char_id integer NOT NULL,
    skill_id integer NOT NULL,
    skill_data1 integer NOT NULL,
    skill_data2 integer NOT NULL,
    CONSTRAINT pk_user_skill_backup PRIMARY KEY (char_id, skill_id)
);

CREATE TABLE user_skill_cooltime (
    char_id integer NOT NULL,
    cooltime_data_cnt smallint NOT NULL,
    data bytea NOT NULL,
    CONSTRAINT pk_user_skill_cooltime PRIMARY KEY (char_id)
);

CREATE TABLE user_skill_skin (
    char_id integer NOT NULL,
    skill_skin_id smallint NOT NULL,
    expire_time integer NULL,
    use_skin smallint NOT NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_user_skill_skin PRIMARY KEY (char_id, skill_skin_id)
);

CREATE TABLE user_stat (
    character_id integer NOT NULL,
    hp integer NULL,
    mp integer NULL,
    dp smallint NULL,
    str smallint NULL,
    vit smallint NULL,
    agi smallint NULL,
    dex smallint NULL,
    kno smallint NULL,
    will smallint NULL,
    physicalright smallint NULL,
    accuracyright smallint NULL,
    criticalright smallint NULL,
    physicalleft smallint NULL,
    accuracyleft smallint NULL,
    criticalleft smallint NULL,
    attackspeed integer NULL,
    movespeed integer NULL,
    magicalboost smallint NULL,
    magicalaccuracy smallint NULL,
    physicaldefend smallint NULL,
    dodge smallint NULL,
    block smallint NULL,
    parry smallint NULL,
    magicresist smallint NULL,
    fireresist smallint NULL,
    airresist smallint NULL,
    waterresist smallint NULL,
    earthresist smallint NULL,
    basehp integer NULL,
    basemp integer NULL,
    basedp smallint NULL,
    basestr smallint NULL,
    basevit smallint NULL,
    baseagi smallint NULL,
    basedex smallint NULL,
    basekno smallint NULL,
    basewill smallint NULL,
    basephysicalright smallint NULL,
    baseaccuracyright smallint NULL,
    basecriticalright smallint NULL,
    basephysicalleft smallint NULL,
    baseaccuracyleft smallint NULL,
    basecriticalleft smallint NULL,
    baseattackspeed integer NULL,
    basemovespeed integer NULL,
    basemagicalboost smallint NULL,
    basemagicalaccuracy smallint NULL,
    basephysicaldefend smallint NULL,
    basedodge smallint NULL,
    baseblock smallint NULL,
    baseparry smallint NULL,
    basemagicresist smallint NULL,
    basefireresist smallint NULL,
    baseairresist smallint NULL,
    basewaterresist smallint NULL,
    baseearthresist smallint NULL,
    castingtimeratio double precision NULL,
    magicalcriticalright smallint NULL,
    magicalcriticalleft smallint NULL,
    phycriticalreducerate smallint NULL,
    magcriticalreducerate smallint NULL,
    phycriticaldamagereduce smallint NULL,
    magcriticaldamagereduce smallint NULL,
    healskillboost smallint NULL,
    basemagicalcriticalright smallint NULL,
    basemagicalcriticalleft smallint NULL,
    basephycriticalreducerate smallint NULL,
    basemagcriticalreducerate smallint NULL,
    basephycriticaldamagereduce smallint NULL,
    basemagcriticaldamagereduce smallint NULL,
    basehealskillboost smallint NULL,
    magicaldefend smallint NULL,
    magicalskillboostresist smallint NULL,
    basemagicaldefend smallint NULL,
    basemagicalskillboostresist smallint NULL,
    magicalleft smallint NULL,
    basemagicalleft smallint NULL,
    basemagicalright smallint NULL,
    magicalright smallint NULL,
    mphealskillboost smallint NULL,
    basemphealskillboost smallint NULL,
    json text DEFAULT NULL NULL,
    CONSTRAINT pk_user_stat PRIMARY KEY (character_id)
);

CREATE TABLE user_title (
    char_id integer NOT NULL,
    title_id integer NOT NULL,
    is_have char(1) NOT NULL,
    expired_time integer DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_title PRIMARY KEY (char_id, title_id)
);

CREATE TABLE user_use_cp (
    char_id integer NOT NULL,
    category smallint NOT NULL,
    enchant_object_id integer NOT NULL,
    "value" smallint NOT NULL,
    accumulated_cp smallint NOT NULL,
    data_id integer NOT NULL,
    CONSTRAINT pk_user_use_cp PRIMARY KEY (char_id, category, enchant_object_id)
);

CREATE TABLE user_useditem_ontrading (
    used_id integer NOT NULL,
    char_id integer NOT NULL,
    trade_type smallint NOT NULL,
    tradeitemid bigint NOT NULL,
    tradeitem_amount bigint NULL,
    useditem_nameid1 integer NULL,
    useditem_amount1 bigint NULL,
    useditem_nameid2 integer NULL,
    useditem_amount2 bigint NULL,
    useditem_nameid3 integer NULL,
    useditem_amount3 bigint NULL,
    used_abysspoint bigint NULL,
    used_money bigint NULL,
    status smallint NOT NULL,
    regdate timestamp NOT NULL,
    useditem_nameid4 integer NULL,
    useditem_amount4 bigint NULL,
    useditem_nameid5 integer NULL,
    useditem_amount5 bigint NULL,
    useditem_nameid6 integer NULL,
    useditem_amount6 bigint NULL,
    useditem_dbid1 bigint NULL,
    useditem_dbid2 bigint NULL,
    useditem_dbid3 bigint NULL,
    useditem_dbid4 bigint NULL,
    useditem_dbid5 bigint NULL,
    useditem_dbid6 bigint NULL,
    CONSTRAINT pk_user_useditem_ontrading PRIMARY KEY (used_id)
);

CREATE TABLE user_wallet (
    id bigint NOT NULL,
    char_id integer NOT NULL,
    name_id integer NOT NULL,
    item_dbid bigint DEFAULT -1 NOT NULL,
    amount bigint NOT NULL,
    create_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_date timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_user_wallet PRIMARY KEY (id)
);

CREATE TABLE user_wardrobe (
    char_id integer NOT NULL,
    slot_id smallint NOT NULL,
    name_id integer NOT NULL,
    CONSTRAINT pk_user_wardrobe PRIMARY KEY (char_id, slot_id)
);

CREATE TABLE user_webnotify (
    id integer NOT NULL,
    char_id integer NOT NULL,
    category integer DEFAULT 0 NOT NULL,
    unsent integer DEFAULT 0 NOT NULL,
    msg text NULL,
    CONSTRAINT pk_user_webnotify PRIMARY KEY (id)
);

CREATE TABLE valid_item_id (
    id integer NOT NULL,
    CONSTRAINT pk_valid_item_id PRIMARY KEY (id)
);

CREATE TABLE valid_skill_id (
    id integer NOT NULL,
    CONSTRAINT pk_valid_skill_id PRIMARY KEY (id)
);

CREATE TABLE vendor_average_dark (
    name_id bigint NOT NULL,
    sold_unit_price bigint NOT NULL,
    sold_date integer NOT NULL
);

CREATE TABLE vendor_average_dark_last_result (
    name_id bigint NOT NULL,
    average_unit_price bigint NOT NULL,
    entire_sold_number integer NOT NULL,
    create_date integer NOT NULL,
    create_datetime timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_date integer NOT NULL,
    update_datetime timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_vendor_average_dark_last_result PRIMARY KEY (name_id)
);

CREATE TABLE vendor_average_light (
    name_id bigint NOT NULL,
    sold_unit_price bigint NOT NULL,
    sold_date integer NOT NULL
);

CREATE TABLE vendor_average_light_last_result (
    name_id bigint NOT NULL,
    average_unit_price bigint NOT NULL,
    entire_sold_number integer NOT NULL,
    create_date integer NOT NULL,
    create_datetime timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    update_date integer NOT NULL,
    update_datetime timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_vendor_average_light_last_result PRIMARY KEY (name_id)
);

CREATE TABLE vendor_item_dark (
    id integer NOT NULL,
    char_id integer NOT NULL,
    user_item_id bigint NOT NULL,
    user_price bigint NOT NULL,
    sale_price bigint NOT NULL,
    commit_amount bigint NOT NULL,
    remain_amount bigint NOT NULL,
    commit_date integer NOT NULL,
    can_buy_partial smallint DEFAULT 0 NOT NULL,
    afterunitfee bigint NOT NULL,
    afterunittax bigint NOT NULL,
    CONSTRAINT pk_vendor_item_dark PRIMARY KEY (id)
);

CREATE TABLE vendor_item_light (
    id integer NOT NULL,
    char_id integer NOT NULL,
    user_item_id bigint NOT NULL,
    user_price bigint NOT NULL,
    sale_price bigint NOT NULL,
    commit_amount bigint NOT NULL,
    remain_amount bigint NOT NULL,
    commit_date integer NOT NULL,
    can_buy_partial smallint DEFAULT 0 NOT NULL,
    afterunitfee bigint NOT NULL,
    afterunittax bigint NOT NULL,
    CONSTRAINT pk_vendor_item_light PRIMARY KEY (id)
);

CREATE TABLE vendor_log_dark (
    id integer NOT NULL,
    char_id integer NOT NULL,
    item_name_id integer NOT NULL,
    sold_price bigint NOT NULL,
    sold_amount bigint NOT NULL,
    remain_amount bigint NOT NULL,
    sold_date integer NOT NULL,
    soul_bound smallint DEFAULT 0 NOT NULL,
    enchant_count smallint DEFAULT 0 NOT NULL,
    skin_name_id integer DEFAULT 0 NOT NULL,
    stat_enchant_0 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val0 smallint DEFAULT 0 NOT NULL,
    stat_enchant_1 smallint DEFAULT 0 NOT NULL,
    stat_enchant_2 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val2 smallint DEFAULT 0 NOT NULL,
    stat_enchant_3 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val3 smallint DEFAULT 0 NOT NULL,
    stat_enchant_4 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val4 smallint DEFAULT 0 NOT NULL,
    stat_enchant_5 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val5 smallint DEFAULT 0 NOT NULL,
    option_count smallint DEFAULT 0 NULL,
    dye_info integer DEFAULT 0 NOT NULL,
    proc_tool_nameid integer DEFAULT 0 NOT NULL,
    stat_enchant_val1 smallint DEFAULT 0 NOT NULL,
    producer varchar(20) DEFAULT '' NOT NULL,
    stat_enchant_name0 integer DEFAULT 0 NULL,
    stat_enchant_name1 integer DEFAULT 0 NULL,
    stat_enchant_name2 integer DEFAULT 0 NULL,
    stat_enchant_name3 integer DEFAULT 0 NULL,
    stat_enchant_name4 integer DEFAULT 0 NULL,
    stat_enchant_name5 integer DEFAULT 0 NULL,
    random_option smallint NULL,
    limit_enchant_count smallint NULL,
    reidentity_count smallint NULL,
    vanish_point integer NULL,
    authorize_count smallint DEFAULT 0 NULL,
    parts_enchant_name0 integer NULL,
    parts_enchant_name1 integer NULL,
    parts_enchant_name2 integer NULL,
    parts_enchant_name3 integer NULL,
    parts_enchant_name4 integer NULL,
    parts_enchant_name5 integer NULL,
    parts_option_count smallint NULL,
    enchant_prob_addition integer NULL,
    option_prob_addition integer NULL,
    after_fee bigint NOT NULL,
    after_tax bigint NOT NULL,
    CONSTRAINT pk_vendor_log_dark PRIMARY KEY (id)
);

CREATE TABLE vendor_log_light (
    id integer NOT NULL,
    char_id integer NOT NULL,
    item_name_id integer NOT NULL,
    sold_price bigint NOT NULL,
    sold_amount bigint NOT NULL,
    remain_amount bigint NOT NULL,
    sold_date integer NOT NULL,
    soul_bound smallint DEFAULT 0 NOT NULL,
    enchant_count smallint DEFAULT 0 NOT NULL,
    skin_name_id integer DEFAULT 0 NOT NULL,
    stat_enchant_0 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val0 smallint DEFAULT 0 NOT NULL,
    stat_enchant_1 smallint DEFAULT 0 NOT NULL,
    stat_enchant_2 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val2 smallint DEFAULT 0 NOT NULL,
    stat_enchant_3 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val3 smallint DEFAULT 0 NOT NULL,
    stat_enchant_4 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val4 smallint DEFAULT 0 NOT NULL,
    stat_enchant_5 smallint DEFAULT 0 NOT NULL,
    stat_enchant_val5 smallint DEFAULT 0 NOT NULL,
    option_count smallint DEFAULT 0 NULL,
    dye_info integer DEFAULT 0 NOT NULL,
    proc_tool_nameid integer DEFAULT 0 NOT NULL,
    stat_enchant_val1 smallint DEFAULT 0 NOT NULL,
    producer varchar(20) DEFAULT '' NOT NULL,
    stat_enchant_name0 integer DEFAULT 0 NULL,
    stat_enchant_name1 integer DEFAULT 0 NULL,
    stat_enchant_name2 integer DEFAULT 0 NULL,
    stat_enchant_name3 integer DEFAULT 0 NULL,
    stat_enchant_name4 integer DEFAULT 0 NULL,
    stat_enchant_name5 integer DEFAULT 0 NULL,
    random_option smallint NULL,
    limit_enchant_count smallint NULL,
    reidentity_count smallint NULL,
    authorize_count smallint DEFAULT 0 NULL,
    vanish_point integer NULL,
    parts_enchant_name0 integer NULL,
    parts_enchant_name1 integer NULL,
    parts_enchant_name2 integer NULL,
    parts_enchant_name3 integer NULL,
    parts_enchant_name4 integer NULL,
    parts_enchant_name5 integer NULL,
    parts_option_count smallint NULL,
    enchant_prob_addition integer NULL,
    option_prob_addition integer NULL,
    after_fee bigint NOT NULL,
    after_tax bigint NOT NULL,
    CONSTRAINT pk_vendor_log_light PRIMARY KEY (id)
);

CREATE TABLE whale_fall_config (
    config_id integer NOT NULL,
    config_name varchar(50) NOT NULL,
    config_value varchar(200) NULL,
    description varchar(500) NULL,
    created_date timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    modified_date timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    CONSTRAINT pk_whale_fall_config PRIMARY KEY (config_id)
);

CREATE TABLE whale_fall_items (
    item_log_id bigint NOT NULL,
    log_id bigint NOT NULL,
    char_id integer NOT NULL,
    user_item_id bigint NOT NULL,
    item_name_id integer NULL,
    amount bigint NULL,
    destination varchar(20) NULL,
    dest_char_id integer NULL,
    price bigint NULL,
    transfer_time timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    CONSTRAINT pk_whale_fall_items PRIMARY KEY (item_log_id)
);

CREATE TABLE whale_fall_kill_record (
    record_id bigint NOT NULL,
    victim_char_id integer NOT NULL,
    killer_char_id integer NOT NULL,
    killer_name varchar(64) NULL,
    kill_time timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    kill_type varchar(20) DEFAULT 'PVP' NULL,
    world_id integer NULL,
    CONSTRAINT pk_whale_fall_kill_record PRIMARY KEY (record_id)
);

CREATE TABLE whale_fall_log (
    log_id bigint NOT NULL,
    char_id integer NOT NULL,
    char_name varchar(64) NULL,
    account_id integer NULL,
    race smallint NULL,
    "level" integer NULL,
    death_count integer NULL,
    fall_mode varchar(20) NULL,
    killer_char_id integer NULL,
    killer_name varchar(64) NULL,
    total_items integer NULL,
    total_value bigint NULL,
    fall_time timestamp DEFAULT CURRENT_TIMESTAMP NULL,
    status varchar(20) DEFAULT 'SUCCESS' NULL,
    CONSTRAINT pk_whale_fall_log PRIMARY KEY (log_id)
);

CREATE TABLE world_bot_channel_info (
    char_id integer NOT NULL,
    account_id integer NOT NULL,
    world_id integer NOT NULL
);

CREATE TABLE world_extcondition (
    id integer NOT NULL,
    world_type smallint NOT NULL,
    world_num integer NOT NULL,
    variable varchar(256) NOT NULL,
    variable_hash integer NOT NULL,
    "value" integer NOT NULL,
    CONSTRAINT pk_world_extcondition PRIMARY KEY (id)
);

-- ── Indexes ──────────────────────────────────────────

CREATE UNIQUE INDEX ix_abyss_op_point ON abyss_op_point (race);
CREATE UNIQUE INDEX ix_abyss_op_spawn ON abyss_op_spawn (npc_name_id);
CREATE INDEX ix_abyss_region_ranking_race_rank ON abyss_region_ranking (race, "rank");
CREATE INDEX ix_abyss_user_defender_abyss_id_update_time ON abyss_user_defender (abyss_id, update_time);
CREATE INDEX ix_abyss_user_owner_abyss_id_update_time ON abyss_user_owner (abyss_id, update_time);
CREATE UNIQUE INDEX uk_account_id ON access_allow_account (account_id, status);
CREATE INDEX ix_server_id_is_deleted ON aion_tv_contents (server_id, is_deleted);
CREATE INDEX ix_bookmark_char_id ON bookmark (char_id);
CREATE INDEX ix_builder_log_char_nm ON builder_log (char_nm);
CREATE UNIQUE INDEX ix_challenge_task_unique ON challenge_task (union_id, "type", task_name_id);
CREATE INDEX ix_enchant_migration ON enchant_migration (enchant, "value");
CREATE INDEX ix_forbidden_char ON forbidden_char (forbidden_char);
CREATE INDEX ix_forbidden_word ON forbidden_word (forbidden_word);
CREATE INDEX ix_game_money_trade_request_id ON game_money_trade (request_id);
CREATE INDEX ix_game_money_trade_seller ON game_money_trade (seller, state);
CREATE UNIQUE INDEX ix_guild_name ON guild ("name");
CREATE INDEX ix_guild_rank ON guild ("rank");
CREATE INDEX ix_guild_history_guild_id ON guild_history (guild_id);
CREATE INDEX ix_guild_name_change_log_master_id ON guild_name_change_log (master_id);
CREATE INDEX ix_guild_warehouse_history_guild_id ON guild_warehouse_history (guild_id, eventdate);
CREATE INDEX ix_owner_id ON house_field (owner_id);
CREATE INDEX ix_owner_id_houseobject ON houseobject (owner_id);
CREATE INDEX ix_char_id ON houseobject_extdata (char_id);
CREATE UNIQUE INDEX uk_instance_id ON instance (instance_id, validity_time);
CREATE INDEX ix_npc_favor ON npc_favor (char_id);
CREATE INDEX ix_npc_favor_char_id ON npc_favor (char_id);
CREATE INDEX ix_npc_limited_sales ON npc_limited_sales (npc_id, item_id);
CREATE INDEX ix_npc_user_sales_log ON npc_user_sales_log (npc_id, item_id, char_id);
CREATE INDEX ix_poll_answer_account_id ON poll_answer (account_id);
CREATE INDEX ix_poll_answer_poll_id_answer_time ON poll_answer (poll_id, answer_time);
CREATE INDEX ix_poll_answer_poll_id_char_id ON poll_answer (poll_id, char_id, account_id);
CREATE INDEX ix_poll_info_status_start_time_end_time ON poll_info (status, start_time, end_time);
CREATE INDEX ix_char_id_qina_manipulate ON qina_manipulate (charid);
CREATE UNIQUE INDEX uk_restricted_item_restricted_id_item_name_id ON restricted_item (restricted_id, item_name_id);
CREATE UNIQUE INDEX uk_trial_account_data ON trial_account_data (account_id);
CREATE INDEX ix_buyerid ON user_auction (buyerid);
CREATE INDEX ix_goodsid ON user_auction (goodsid);
CREATE INDEX ix_goodsid_user_auctionfilter ON user_auctionfilter (goodsid);
CREATE INDEX ix_ownerid ON user_betting (ownerid);
CREATE INDEX ix_account_id ON user_bingo_reward (account_id);
CREATE INDEX ix_user_block_block_id ON user_block (block_id);
CREATE INDEX ix_inviter_id ON user_buddy_offline (inviter_id);
CREATE INDEX ix_user_buddy_date ON user_buddy_offline (createdate);
CREATE INDEX ix_user_id ON user_buddy_offline (user_id);
CREATE INDEX ix_user_buddy1_buddy_id ON user_buddy1 (buddy_id);
CREATE INDEX ix_user_captcha_char_id ON user_captcha (char_id);
CREATE INDEX ix_user_change_log_char_id_change_type_change_time ON user_change_log (char_id, change_type, change_time);
CREATE INDEX ix_user_comment_char_id ON user_comment (char_id);
CREATE INDEX ix_user_customize_history_char_id ON user_customize_history (char_id);
CREATE INDEX ix_delete_complete_date ON user_data (delete_complete_date, delete_date);
CREATE INDEX ix_delete_date ON user_data (delete_date, account_id);
CREATE INDEX ix_user_data_account_id ON user_data (account_id);
CREATE INDEX ix_user_data_account_name ON user_data (account_name);
CREATE INDEX ix_user_data_guild_id ON user_data (guild_id);
CREATE UNIQUE INDEX uk_user_data_user_id_delete_date ON user_data (user_id, delete_date);
CREATE INDEX ix_disassembly_retry_list ON user_disassembly_retry (charid, isdelete);
CREATE INDEX ix_disassembly_retry_update ON user_disassembly_retry (charid, itemid);
CREATE INDEX ix_char_id_user_equipment_change_flag ON user_equipment_change_flag (char_id);
CREATE INDEX ix_char_id_user_equipment_change_item ON user_equipment_change_item (char_id);
CREATE INDEX ix_seller ON user_escrow (seller);
CREATE INDEX ix_account_id_user_extra_info ON user_extra_info (account_id);
CREATE INDEX ix_user_familiar_char_id ON user_familiar (char_id);
CREATE INDEX ix_goods_id ON user_grace (goods_id);
CREATE INDEX ix_owner_id_user_grace ON user_grace (owner_id);
CREATE INDEX ix_user_guild_join_application_guild_id ON user_guild_join_application (guild_id);
CREATE INDEX ix_user_item_char_id_world_id ON user_instance (char_id, world_id);
CREATE INDEX ix_char_world ON user_instance_achievement (char_id, world_id, spawn_page, version);
CREATE INDEX ix_user_item_char_id_warehouse_slot ON user_item (char_id, warehouse, slot);
CREATE INDEX ix_char_id_user_item_ext ON user_item_ext (char_id);
CREATE INDEX ix_user_item_option ON user_item_option (char_id);
CREATE INDEX ix_user_item_sealed_char_id ON user_item_sealed (char_id);
CREATE UNIQUE INDEX ix_user_item_signature_char_id ON user_item_signature (char_id);
CREATE INDEX ix_user_mail_to_id_arrive_time ON user_mail (to_id, arrive_time, express_mail, state);
CREATE INDEX ncl_char_id_achieve_id ON user_monster_achievement (char_id, achieve_id);
CREATE INDEX ix_user_move_service_log_char_id ON user_move_service_log (char_id);
CREATE INDEX ix_user_name_change_log_char_id ON user_name_change_log (char_id);
CREATE INDEX ix_user_pet_char_id_name_id ON user_pet (char_id, name_id);
CREATE UNIQUE INDEX uk_char_id_sv_id ON user_petition_msg (char_id, petition_sv_id);
CREATE UNIQUE INDEX ix_user_petition_web_char_id ON user_petition_web (char_id);
CREATE INDEX ix_user_promotion_cooltime ON user_promotion_cooltime (promotion_id);
CREATE INDEX ix_user_punishment_account_id ON user_punishment (account_id);
CREATE INDEX ix_user_punishment_char_id ON user_punishment (char_id);
CREATE UNIQUE INDEX ix_user_rank ON user_rank (char_id, rank_id);
CREATE UNIQUE INDEX ix_char_rate ON user_rate (char_id, rate_id);
CREATE INDEX ix_char_id_user_server_transfer ON user_server_transfer (char_id);
CREATE INDEX ix_user_use_cp ON user_use_cp (char_id);
CREATE INDEX ix_char_id_user_useditem_ontrading ON user_useditem_ontrading (char_id, tradeitemid, trade_type);
CREATE INDEX ix_char_id_user_wallet ON user_wallet (char_id);
CREATE UNIQUE INDEX ix_user_webnotify_char_id ON user_webnotify (char_id, category);
CREATE INDEX ix_darkcommit_date ON vendor_item_dark (commit_date);
CREATE INDEX ix_vendor_item_dark_char_id ON vendor_item_dark (char_id);
CREATE UNIQUE INDEX ix_vendor_item_dark_user_item_id ON vendor_item_dark (user_item_id);
CREATE INDEX ix_lightcommit_date ON vendor_item_light (commit_date);
CREATE INDEX ix_vendor_item_light_char_id ON vendor_item_light (char_id);
CREATE UNIQUE INDEX ix_vendor_item_light_user_item_id ON vendor_item_light (user_item_id);
CREATE INDEX ix_vendor_log_dark_char_id ON vendor_log_dark (char_id);
CREATE INDEX ix_vendor_log_light_char_id ON vendor_log_light (char_id);
CREATE UNIQUE INDEX uq__whale_fa__dacdddeadaa83d26 ON whale_fall_config (config_name);
CREATE INDEX ix_worldnum_variable ON world_extcondition (world_num, variable_hash);
