-- ============================================================
-- PL/pgSQL Functions converted from LIVE_AionGM
-- Source: LIVE_AionGM_schema.json
-- Total: 183 procedures
-- Auto-converted: 128
-- Needs review: 55
-- Needs manual work: 0
-- ============================================================

-- Confidence Legend:
--   [AUTO]   - Fully automatic conversion
--   [REVIEW] - Likely correct, please verify
--   [MANUAL] - Needs human intervention

-- [OK] [AUTO] TblGameNoticeScheduleDA_SrchTransHistory

CREATE OR REPLACE FUNCTION tblgamenoticescheduleda_srchtranshistory(
    p_notice_id varchar(30),
    p_cur_yyyymmdd varchar(8),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_communication_cd varchar(30),
    p_notice_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) sendable from tbl_game_notice_schedule t1, tbl_game_notice_history t2 where t1.notice_id = t2.notice_id and t1.notice_id = p_notice_id and t1.period_hour = p_period_hour and t1.period_min = p_period_min and (t1.communication_cd = p_communication_cd OR t1.communication_cd = 'TRA') and t1.notice_status = p_notice_status and TO_CHAR(t2.regdate, 'YYYYMMDD') = p_cur_yyyymmdd;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticeWorldDA_SrchNoticeWorld

CREATE OR REPLACE FUNCTION tblgamenoticeworldda_srchnoticeworld(
    p_notice_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT notice_world_id, notice_id, world_id from tbl_game_notice_world where notice_id = p_notice_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameWorldInfoDA_SrchALLChannels
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchallchannels(
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select zone_id, zone_nm, channel_num ' || ' from tbl_game_world_info ' || ' where world_id = ''' || p_world_id || ''' and zone_id !=0 ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameWorldInfoDA_SrchChannel

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchchannel(
    p_world_id varchar(5),
    p_channel_num varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT world_type, zone_id, zone_nm, channel_num from tbl_game_world_info where world_id = p_world_id::integer and zone_id !=0 and channel_num=p_channel_num and zone_id <= 719999999 order by world_type desc;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameWorldInfoDA_SrchCurWorldInfo
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchcurworldinfo(
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select world_type as light_char_count, channel_num as dark_char_count , light_users, dark_users, npc_count as total_cnt, npc_count-pc_store_light_users as lobby_cnt, pc_store_light_users as world_cnt,   ' || ' (select sum(pc_store_light_users) from TBL_GAME_WORLD_INFO where world_id=''' || p_world_id || ''' and zone_id!=0) sum_pc_store_light_users,  ' || ' (select sum(pc_store_dark_users) from TBL_GAME_WORLD_INFO where world_id=''' || p_world_id || ''' and zone_id!=0) sum_pc_store_dark_users,  ' || ' (select sum(npc_count) from TBL_GAME_WORLD_INFO where world_id=''' || p_world_id || ''' and zone_id!=0) sum_npc_count  ' || ' from TBL_GAME_WORLD_INFO   ' || ' where world_id=''' || p_world_id || ''' and zone_id=0 ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameWorldInfoDA_SrchGameServerInfoByStatus
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchgameserverinfobystatus(
    p_server_status varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select world_id, server_id, server_status, free_disk, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from tbl_game_server_info ' || ' where server_status = ''' || p_server_status || '''  and world_id=''15'' ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameWorldInfoDA_SrchGameServerInfoByWorldID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchgameserverinfobyworldid(
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select server_id, server_status, free_disk, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from tbl_game_server_info ' || ' where world_id = ''' || p_world_id || ''' order by server_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameWorldInfoDA_SrchGameWorldInfoByWorldID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchgameworldinfobyworldid(
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select world_type, zone_id, zone_nm, channel_num, light_users, dark_users, npc_count, pc_store_light_users, pc_store_dark_users, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from tbl_game_world_info ' || ' where world_id = ''' || p_world_id || ''' and world_type!=''NA'' and zone_id <''900000000'' order by zone_id asc';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGroupFuncDA_SrchGroupsByGroupID

CREATE OR REPLACE FUNCTION tblgroupfuncda_srchgroupsbygroupid(
    p_group_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT MENU_GROUP_CODE, group_func_id, group_id, t1.menu_id, t2.menu_code, T2.MENU_DEPTH, search_auth, view_auth, insert_auth, update_auth, delete_auth from tbl_group_func t1, tbl_admin_menu t2 where t1.group_id = p_group_id::integer and t1.menu_id = t2.menu_id ORDER BY t2.MENU_GROUP_CODE ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblItemChangeInfoDA_SrchLog
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblitemchangeinfoda_srchlog(
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := 'select TO_CHAR(regdate, ''YYYY/MM/DD'') regdate, sum(plus_value) sum_plus_value, sum(minus_value) sum_minus_value ' || 'from TBL_ITEM_CHANGE_INFO ' || 'where regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || 'and world_id=''' || p_world_id || ''' ';
    END IF;
    v_sql := v_sql || 'group by TO_CHAR(regdate, ''YYYY/MM/DD'') ' || 'order by regdate asc';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblItemChangeInfoDA_SrchViewCateoryLog
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblitemchangeinfoda_srchviewcateorylog(
    p_the_date varchar(20),
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := 'select sub_type, sum(plus_value) sum_plus_value, sum(minus_value) sum_minus_value ' || 'from TBL_ITEM_CHANGE_INFO ' || 'where regdate between ''' || p_the_date || ''' and ''' || p_the_date || ' 23:59:59.999'' ';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || 'and world_id=''' || p_world_id || ''' ';
    END IF;
    v_sql := v_sql || 'group by sub_type';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblItemChangeInfoDA_SrchViewLog
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblitemchangeinfoda_srchviewlog(
    p_the_date varchar(20),
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := 'select TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, * ' || 'from TBL_ITEM_CHANGE_INFO ' || 'where regdate between ''' || p_the_date || ''' and ''' || p_the_date || ' 23:59:59.999''';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || 'and world_id=''' || p_world_id || ''' ';
    END IF;
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblItemPresetDA_SrchAllPreset

CREATE OR REPLACE FUNCTION tblitempresetda_srchallpreset(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.PRESET_ID, T1.PRESET_NM, T1.IS_DELETED, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, T1.LOGIN_ID, T2.LOGIN_NM FROM TBL_ITEM_PRESET T1, TBL_ADMIN_USER T2 WHERE T1.LOGIN_ID = T2.LOGIN_ID AND T1.IS_DELETED='Y' order by regdate desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblItemPresetDA_SrchPresetItemsByID

CREATE OR REPLACE FUNCTION tblitempresetda_srchpresetitemsbyid(
    p_preset_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.ITEM_ID, T1.ITEM_CNT, T1.ITEM_PKG_CNT, T1.ITEM_ENCHANT FROM TBL_PRESET_ITEM_ID T1 WHERE T1.PRESET_ID=p_preset_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblLogFilesDA_SrchLogfiles
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbllogfilesda_srchlogfiles(
    p_login_id varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_logfile_type varchar(20),
    p_is_shared char(1),
    p_is_deleted char(1),
    p_top_count varchar(5),
    p_is_correct varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select top ' || p_top_count || ' logfile_id, logfile_type, logfile_name, logfile_size, logfile_info, is_shared, is_deleted, login_id, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_LOG_FILES ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_login_id != 'null' THEN
    IF p_is_correct IS NOT NULL THEN
    v_sql := v_sql || ' and login_id = ''' || p_login_id || '''';
    ELSE
    v_sql := v_sql || ' and login_id like ''%' || p_login_id || '%''';
    END IF;
    END IF;
    IF p_logfile_type IS NOT NULL THEN
    v_sql := v_sql || ' and logfile_type = ''' || p_logfile_type || '''';
    END IF;
    IF p_is_shared IS NOT NULL THEN
    v_sql := v_sql || ' and is_shared = ''' || p_is_shared || '''';
    END IF;
    IF p_is_deleted IS NOT NULL THEN
    v_sql := v_sql || ' and is_deleted = ''' || p_is_deleted || '''';
    END IF;
    v_sql := v_sql || ' order by regdate desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblLogFilesDA_SrchMyLogfiles
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbllogfilesda_srchmylogfiles(
    p_login_id varchar(30),
    p_logfile_type varchar(20),
    p_is_shared char(1),
    p_is_deleted char(1),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select top ' || p_top_count || ' logfile_id, logfile_type, logfile_name, logfile_size, logfile_info, is_shared, is_deleted, login_id, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_LOG_FILES ' || ' where (login_id = ''' || p_login_id || ''' or is_shared = ''' || p_is_shared || ''') ';
    IF p_logfile_type IS NOT NULL THEN
    v_sql := v_sql || ' and logfile_type = ''' || p_logfile_type || '''';
    END IF;
    IF p_is_deleted IS NOT NULL THEN
    v_sql := v_sql || ' and is_deleted = ''' || p_is_deleted || '''';
    END IF;
    v_sql := v_sql || ' order by regdate desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblLogFilesDA_SrchMyLogfilesByCond
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbllogfilesda_srchmylogfilesbycond(
    p_login_id varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_logfile_type varchar(20),
    p_is_shared char(1),
    p_is_deleted char(1),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select top ' || p_top_count || ' logfile_id, logfile_type, logfile_name, logfile_size, logfile_info, is_shared, is_deleted, login_id, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_LOG_FILES ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_login_id != 'null' THEN
    v_sql := v_sql || ' AND (LOGIN_ID = ''' || p_login_id || ''' OR IS_SHARED = ''' || p_is_shared || ''')';
    END IF;
    IF p_logfile_type IS NOT NULL THEN
    v_sql := v_sql || ' and logfile_type = ''' || p_logfile_type || '''';
    END IF;
    IF p_is_deleted IS NOT NULL THEN
    v_sql := v_sql || ' and is_deleted = ''' || p_is_deleted || '''';
    END IF;
    v_sql := v_sql || ' order by regdate desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblLogFilesDAO_InsertFile

CREATE OR REPLACE FUNCTION tbllogfilesdao_insertfile(
    p_logfile_type varchar(20),
    p_logfile_name varchar(80),
    p_logfile_size varchar(20),
    p_logfile_info varchar(300),
    p_is_shared char(1),
    p_is_deleted char(1),
    p_login_id varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_LOG_FILES VALUES(p_logfile_type, p_logfile_name, p_logfile_size, p_logfile_info, p_is_shared, p_is_deleted, p_login_id, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMailDA_SrchMail
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmailda_srchmail(
    p_mail_type varchar(30),
    p_mail_status varchar(1)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select mail_id, mail_type, mail_title, mail_intro, mail_content, mail_tail, mail_status, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from tbl_mail ' || ' where mail_type = ''' || p_mail_type || ''' and mail_status=''' || p_mail_status || ''' order by mail_id desc  LIMIT 1';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMailShootHistoryDA_SrchMail
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmailshoothistoryda_srchmail(
    p_char_nm varchar(50),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_world_id varchar(3)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1500);
BEGIN
    v_sql := ' select reason, mail_id, world_id, char_nms, mail_subject, mail_content, mail_kina, mail_name_id, mail_amount, mail_express, err_info, status, is_deleted, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_MAIL_SHOOT_HISTORY  ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_char_nm != 'null' THEN
    v_sql := v_sql || ' and char_nms like ''%' || p_char_nm || '%''  ';
    END IF;
    IF p_world_id != 'null' THEN
    v_sql := v_sql || ' and world_id=''' || p_world_id || '''  ';
    END IF;
    v_sql := v_sql || ' order by regdate desc, world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMemoDA_SrchAllByRefPKID

CREATE OR REPLACE FUNCTION tblmemoda_srchallbyrefpkid(
    p_ref_pk_id varchar(30),
    p_memo_status char(1),
    p_world_id integer,
    p_memo_type char(1) DEFAULT 'C'
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.char_nm, t1.world_id, t1.memo_id, t1.menu_id, t1.ref_pk_id, t1.memo_info, t1.memo_status, t1.login_id, t3.login_nm, t1.regdate, t2.menu_code from tbl_memo t1, tbl_admin_menu t2, tbl_admin_user t3 where t1.ref_pk_id=p_ref_pk_id and t1.login_id = t3.login_id and t1.menu_id = t2.menu_id and t1.memo_status=p_memo_status and t1.world_id = p_world_id::integer and t1.memo_type=p_memo_type order by t1.memo_id desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMemoDA_SrchMemo
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmemoda_srchmemo(
    p_char_nm varchar(50),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_world_id varchar(3),
    p_memo_type char(1) DEFAULT 'C'
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1500);
BEGIN
    v_sql := ' select t1.memo_id, t1.menu_id, t1.ref_pk_id, t1.char_nm, t1.memo_info, t1.memo_status, t1.login_id, t1.world_id, TO_CHAR(t1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, ' || ' t2.menu_code, t3.login_nm ' || ' from tbl_memo t1, tbl_admin_menu t2, tbl_admin_user t3 ' || ' where t1.login_id = t3.login_id and t1.menu_id = t2.menu_id and t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_char_nm != 'null' THEN
    v_sql := v_sql || ' and t1.char_nm=''' || p_char_nm || '''  ';
    END IF;
    IF p_world_id != 'null' THEN
    v_sql := v_sql || ' and t1.world_id=''' || p_world_id || '''  ';
    END IF;
    v_sql := v_sql || ' order by t1.regdate desc, t1.world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMyFuncDA_SrchByCond
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmyfuncda_srchbycond(
    p_login_id varchar(30),
    p_login_nm varchar(50),
    p_search_auth char(1),
    p_view_auth char(1),
    p_insert_auth char(1),
    p_update_auth char(1),
    p_delete_auth char(1),
    p_is_correct varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' SELECT T2.ADMIN_ID, T2.LOGIN_ID, T2.LOGIN_NM, ' || '	    T1.AUTH_ID, T1.MENU_ID, T1.REG_LOGIN_ID, T1.SEARCH_AUTH, T1.VIEW_AUTH, T1.INSERT_AUTH, T1.UPDATE_AUTH, T1.DELETE_AUTH, T1.IS_DELETED, ' || '		T3.MENU_CODE ' || ' from TBL_MY_FUNC T1, TBL_ADMIN_USER T2, TBL_ADMIN_MENU T3 ' || ' WHERE	T1.LOGIN_ID = T2.LOGIN_ID AND T1.MENU_ID = T3.MENU_ID ';
    IF p_login_id != 'null' THEN
    IF p_is_correct IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.LOGIN_ID = ''' || p_login_id || '''';
    ELSE
    v_sql := v_sql || ' AND T1.LOGIN_ID like ''%' || p_login_id || '%''';
    END IF;
    END IF;
    IF p_login_nm != 'null' THEN
    IF p_is_correct IS NOT NULL THEN
    v_sql := v_sql || ' AND T2.LOGIN_NM = ''' || p_login_nm || '''';
    ELSE
    v_sql := v_sql || ' AND T2.LOGIN_NM like ''%' || p_login_nm || '%''';
    END IF;
    END IF;
    IF p_search_auth IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.SEARCH_AUTH = ''' || p_search_auth || '''';
    END IF;
    IF p_view_auth IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.view_auth = ''' || p_view_auth || '''';
    END IF;
    IF p_insert_auth IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.insert_auth = ''' || p_insert_auth || '''';
    END IF;
    IF p_update_auth IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.update_auth = ''' || p_update_auth || '''';
    END IF;
    IF p_delete_auth IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.delete_auth = ''' || p_delete_auth || '''';
    END IF;
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyFuncDA_SrchMyAuthByLoginID

CREATE OR REPLACE FUNCTION tblmyfuncda_srchmyauthbyloginid(
    p_login_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.MENU_GROUP_CODE, t1.menu_id, t1.menu_code, T1.MENU_DEPTH, T2.search_auth, T2.view_auth, T2.insert_auth, T2.update_auth, T2.delete_auth FROM TBL_ADMIN_MENU T1, TBL_MY_FUNC T2 WHERE T1.MENU_ID = T2.MENU_ID AND T2.LOGIN_ID = p_login_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMyFuncDA_SrchMyFunc
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmyfuncda_srchmyfunc(
    p_login_id varchar(50)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select T1.AUTH_ID, T1.LOGIN_ID, T1.MENU_ID, T1.SEARCH_AUTH, T1.VIEW_AUTH, T1.INSERT_AUTH, T1.UPDATE_AUTH, T1.DELETE_AUTH, T1.REG_LOGIN_ID, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, ' || ' T2.MENU_CODE, T2.MENU_GROUP_CODE, T2.MENU_DEPTH ' || ' from TBL_MY_FUNC T1, TBL_ADMIN_MENU T2 ' || ' where ' || ' T1.login_id = ''' || p_login_id || ''' AND ' || ' T1.MENU_ID = T2.MENU_ID';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMyGroupDA_AuthCheck
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmygroupda_authcheck(
    p_login_id varchar(30),
    p_menu_id varchar(50),
    p_action_code varchar(50)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_cond varchar(30);
    v_sql varchar(1000);
BEGIN
    v_cond := 'T2.' || p_action_code;
    v_sql := ' SELECT SUM(A.CNT1) MY_AUTH ' || ' FROM ' || ' ( ' || ' 	SELECT COUNT(*) CNT1 ' || ' 		FROM TBL_MY_FUNC ' || ' 		WHERE  ' || '			IS_DELETED = ''Y'' AND ' || ' 			LOGIN_ID = ''' || p_login_id || ''' AND ' || ' 			MENU_ID = ''' || p_menu_id || ''' AND ' || p_action_code || '=''Y'' ' || ' 	UNION ' || ' 		SELECT COUNT(*) CNT1 ' || ' 		FROM TBL_MY_GROUP T1, TBL_GROUP_FUNC T2, TBL_ADMIN_GROUP T3 ' || ' 		WHERE  ' || ' 			T1.LOGIN_ID = ''' || p_login_id || ''' AND ' || ' 			T1.GROUP_ID = T3.GROUP_ID AND T3.IS_DELETED = ''Y'' AND ' || ' 			T1.GROUP_ID = T2.GROUP_ID AND ' || ' 			T2.MENU_ID = ''' || p_menu_id || ''' AND ' || v_cond || '= ''Y'' ' || ' ) A ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblMyGroupDA_SrchMyGroup
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblmygroupda_srchmygroup(
    p_login_id varchar(50)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select t1.group_id, t1.group_nm,  t2.login_id, t2.mygroup_id ' || ' from tbl_admin_group t1, tbl_my_group t2 ' || ' where  t1.group_id = t2.group_id and ' || ' t2.login_id = ''' || p_login_id || ''' ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyGroupDA_SrchUsersByGroupID

CREATE OR REPLACE FUNCTION tblmygroupda_srchusersbygroupid(
    p_group_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.mygroup_id, t1.login_id, t1.group_id, t2.login_nm, t2.admin_id from tbl_my_group t1, tbl_admin_user t2 where t1.login_id = t2.login_id and group_id = p_group_id::integer;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyPresetDA_SrchCategoryCodeByPresetID

CREATE OR REPLACE FUNCTION tblmypresetda_srchcategorycodebypresetid(
    p_preset_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT category_code from tbl_mypreset where preset_id = p_preset_id group by category_code;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyPresetDA_SrchPresetByID

CREATE OR REPLACE FUNCTION tblmypresetda_srchpresetbyid(
    p_preset_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT MYPRESET_ID, PRESET_ID, LOG_ID, CATEGORY_CODE FROM TBL_MYPRESET WHERE	PRESET_ID = p_preset_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchCheckServers

CREATE OR REPLACE FUNCTION tblmyworldda_srchcheckservers(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.WORLD_STATUS_INFO_ID, t1.WORLD_ID, t1.SERVER_NM, t1.concurrent_users, t1.CPU_USAGE, t1.FREE_PHY_MEMORY, t1.PROCESS_MEMORY, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (REGDATE)::timestamp) / 60)::integer AS is_alive from TBL_WORLD_STATUS_INFO t1 where (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (REGDATE)::timestamp) / 60)::integer >= 2 order by t1.WORLD_ID desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchConcurrentMaxMinSum

CREATE OR REPLACE FUNCTION tblmyworldda_srchconcurrentmaxminsum(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT sum(CAST(max_concurrent_users AS bigint)) sum_max_concurrent_users, sum(CAST(min_concurrent_users AS bigint)) sum_min_concurrent_users from TBL_WORLD_CONCURRENT_INFO;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aiongm_create_tbl_admin_log_per_month
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION aiongm_create_tbl_admin_log_per_month(
    p_logdate varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := 'CREATE TABLE TBL_ADMIN_LOG_' || p_logdate || ' ' || '(  ' || '	ADMIN_LOGID		INT		IDENTITY(1,1)	NOT NULL, ' || '	LOGIN_ID		NVARCHAR(30)	COLLATE Japanese_CI_AS	NOT NULL,' || '	ADMIN_IP		NVARCHAR(15)			NOT NULL,  ' || '	MENU_ID			INT						NOT NULL,  ' || '	ACTION_CODE		NVARCHAR(30)			NOT NULL, 	 ' || '	REGDATE			DATETIME				NOT NULL,  ' || '	LOG_INFO		NVARCHAR(3000)			NOT NULL  ' || ') ';
    EXECUTE v_sql;
    v_sql := 'CREATE CLUSTERED INDEX TBL_ADMIN_LOG_' || p_logdate || ' ON TBL_ADMIN_LOG_' || p_logdate || '(regdate ASC) ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchGWWorldServerStatus

CREATE OR REPLACE FUNCTION tblmyworldda_srchgwworldserverstatus(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.WORLD_STATUS_INFO_ID, t1.WORLD_ID, t1.SERVER_NM, t1.concurrent_users, t1.CPU_USAGE, t1.FREE_PHY_MEMORY, t1.PROCESS_MEMORY, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (REGDATE)::timestamp) / 60)::integer AS is_alive from TBL_WORLD_STATUS_INFO t1 where t1.world_id=1 and t1.SERVER_NM=777;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] commit_test

CREATE OR REPLACE FUNCTION commit_test(
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Transaction managed by PG function context
    insert into test values('222','ok','10');
    insert into test values('한글','ok','10');
    -- COMMIT (implicit in PG function)
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyMaxMinWorldServerStatus

CREATE OR REPLACE FUNCTION tblmyworldda_srchmymaxminworldserverstatus(
    p_login_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_WORLD_CONCURRENT_INFO t1, TBL_MY_WORLD t2 where t1.world_id = t2.world_id and t2.login_id=p_login_id AND T2.SERVER_TYPE = 0 order by t1.WORLD_ID asc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] DBManager_DBManager

CREATE OR REPLACE FUNCTION dbmanager_dbmanager(
    p_world_id varchar(5),
    p_server_nm varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT server_url from tbl_world_server_info where world_id = p_world_id::integer and server_nm = p_server_nm;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyWorlds

CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworlds(
    p_login_id varchar(50),
    p_server_type smallint
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.MY_WORLD_ID, T1.LOGIN_ID, T2.WORLD_ID,  CAST(T2.WORLD_ID AS varchar(10)) || '  ' || T2.WORLD_NM as WORLD_NM from TBL_MY_WORLD T1, TBL_WORLD_INFO T2, TBL_WORLD_INFO T3 WHERE T1.LOGIN_ID = p_login_id AND T1.SERVER_TYPE = p_server_type AND T1.WORLD_ID = T2.WORLD_ID AND T1.WORLD_ID = T3.WORLD_ID AND T3.WORLD_STATUS = 'Y' AND T3.SERVER_TYPE = 0 order by T2.WORLD_ID asc;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] GM_UserDataDA_SrchAbuseQina
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION gm_userdatada_srchabuseqina(
    p_world_id varchar(5),
    p_user_id varchar(30),
    p_account_name varchar(50),
    p_bx_char_id varchar(25),
    p_view_count varchar(5),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(4000);
    v_tmp integer;
    v_sql_etc varchar(1000);
BEGIN
    v_sql_etc := ' and delete_type != ''10000'' ';
    IF p_user_id != 'null' THEN
    v_sql_etc := v_sql_etc || ' and user_id = ''' || p_user_id || '''';
    END IF;
    IF p_bx_char_id != 'null' THEN
    v_sql_etc := v_sql_etc || ' and char_id = ''' || p_bx_char_id || '''';
    END IF;
    IF p_account_name != 'null' THEN
    v_sql_etc := v_sql_etc || ' AND account_name = ''' || p_account_name || '''';
    END IF;
    v_sql := ' select top ' || p_view_count || ' 	delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server,	' || ' 	TO_CHAR(create_date, ''YYYY-MM-DD HH24:MI:SS'') create_date, CAST(gender AS char) gender, CAST(race AS char) race, CAST(class AS char) class, CAST(lev AS char) lev, CAST(builder AS char) builder, exp, world,	' || '   case ' || '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' || '     WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' || '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' || '   end as logonoff, t2.* ' || ' from user_data t1, qina_manipulate t2' || ' where t1.char_id=t2.charid and t2.qina_id not in(select top ' || p_top_count || ' t2.qina_id from user_data t1, qina_manipulate t2 where t1.char_id=t2.charid and org_server=''' || p_world_id || ''' ' || v_sql_etc || '  order by t2.qina_id desc) ';
    v_sql := v_sql || v_sql_etc;
    v_sql := v_sql || ' and org_server = ''' || p_world_id || '''';
    v_sql := v_sql || ' order by t2.qina_id desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyWorldsCount

CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworldscount(
    p_login_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) world_cnt from tbl_my_world where login_id=p_login_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] GM_UserItemDA_SrchMyCompoundItems

CREATE OR REPLACE FUNCTION gm_useritemda_srchmycompounditems(
    p_char_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.tid, t1.obtain_skin_type, t1.expire_skin_time, t1.expired_time, t1.buy_amount, t1.buy_duration, t1.option_count, t1.id, t1.char_id, t1.name_id, t1.amount, t1.slot_id, t1.slot, t1.warehouse, TO_CHAR(t1.create_date, 'YYYY-MM-DD HH24:MI:SS') create_date, TO_CHAR(t1.update_date, 'YYYY-MM-DD HH24:MI:SS') update_date, t1.soul_bound, t1.enchant_count, t1.skin_name_id, t1.stat_enchant_0, t1.stat_enchant_val0, t1.stat_enchant_1, t1.stat_enchant_val1, t1.stat_enchant_2, t1.stat_enchant_val2, t1.stat_enchant_3, t1.stat_enchant_val3, t1.stat_enchant_4, t1.stat_enchant_val4, t1.stat_enchant_5, t1.stat_enchant_val5, t1.dye_info, t1.proc_tool_nameid, t1.producer, t2.id sub_id, t2.name_id sub_name_id, t2.enchant_count sub_enchant_count, t2.skin_name_id sub_skin_name_id, t2.stat_enchant_0 sub_stat_enchant_0, t2.stat_enchant_val0 sub_stat_enchant_val0, t2.stat_enchant_1 sub_stat_enchant_1, t2.stat_enchant_val1 sub_stat_enchant_val1, t2.stat_enchant_2 sub_stat_enchant_2, t2.stat_enchant_val2 sub_stat_enchant_val2, t2.stat_enchant_3 sub_stat_enchant_3, t2.stat_enchant_val3 sub_stat_enchant_val3, t2.stat_enchant_4 sub_stat_enchant_4, t2.stat_enchant_val4 sub_stat_enchant_val4, t2.stat_enchant_5 sub_stat_enchant_5, t2.stat_enchant_val5 sub_stat_enchant_val5 from user_item t1, user_item t2 where t1.char_id = p_char_id::integer and t1.char_id=t2.char_id and t2.main_item_dbid != 0 and t2.warehouse=16 and t1.id=t2.main_item_dbid;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyWorldServerStatus

CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworldserverstatus(
    p_login_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.WORLD_STATUS_INFO_ID, t1.WORLD_ID, t1.SERVER_NM, t1.concurrent_users, t1.CPU_USAGE, t1.FREE_PHY_MEMORY, t1.PROCESS_MEMORY, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (REGDATE)::timestamp) / 60)::integer AS is_alive from TBL_WORLD_STATUS_INFO t1, TBL_MY_WORLD t2 where t1.world_id = t2.world_id AND T2.SERVER_TYPE = 0 and t2.login_id=p_login_id and t1.SERVER_NM != 777 order by t1.WORLD_ID desc;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] GM_UserItemDAO_AddCompound
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION gm_useritemdao_addcompound(
    p_char_id integer,
    p_item_id bigint,
    p_main_item_dbid bigint
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    -- Transaction managed by PG function context
    IF EXISTS (select id from user_item where id = p_main_item_dbid and main_item_dbid != 0 and char_id = p_char_id::integer) THEN
    RAISE EXCEPTION 'Rollback requested';
    RETURN 1;
    END IF;
    IF EXISTS (select id from user_item where main_item_dbid = p_main_item_dbid and warehouse != 10 and char_id = p_char_id::integer) THEN
    RAISE EXCEPTION 'Rollback requested';
    RETURN 2;
    END IF;
    IF EXISTS (select id from user_item where main_item_dbid = p_item_id and warehouse != 10 and char_id = p_char_id::integer) THEN
    RAISE EXCEPTION 'Rollback requested';
    RETURN 3;
    END IF;
    IF EXISTS (select id from user_item where id = p_item_id and main_item_dbid != 0 and char_id = p_char_id::integer) THEN
    RAISE EXCEPTION 'Rollback requested';
    RETURN 4;
    ELSE
    update user_item set warehouse = 16, main_item_dbid = p_main_item_dbid, update_date=CURRENT_TIMESTAMP where id = p_item_id and char_id = p_char_id::integer;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyWorldServerStatusForMaxMin

CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworldserverstatusformaxmin(
    p_server_nm varchar(3)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.WORLD_STATUS_INFO_ID, t1.WORLD_ID, t1.SERVER_NM, t1.concurrent_users, t1.CPU_USAGE, t1.FREE_PHY_MEMORY, t1.PROCESS_MEMORY, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate from TBL_WORLD_STATUS_INFO t1 where t1.server_nm = p_server_nm;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] GM_UserItemDAO_DelCompoundRecovery
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION gm_useritemdao_delcompoundrecovery(
    p_char_id integer,
    p_item_id bigint,
    p_warehouse integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_main_item_dbid bigint;
BEGIN
    -- Transaction managed by PG function context
    SELECT main_item_dbid INTO v_main_item_dbid FROM user_item where id = p_item_id and char_id = p_char_id::integer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF (v_rowcount = 0) THEN
    RAISE EXCEPTION 'Rollback requested';
    RETURN 1;
    END IF;
    IF not EXISTS (select id from user_item where warehouse=16 and main_item_dbid=v_main_item_dbid) THEN
    update user_item set warehouse = p_warehouse::integer where warehouse=17 and id = p_item_id and char_id = p_char_id::integer;
    ELSE
    RAISE EXCEPTION 'Rollback requested';
    RETURN 2;
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchMyWorldsNotAll

CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworldsnotall(
    p_login_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.MY_WORLD_ID, T1.LOGIN_ID, T2.WORLD_ID,  CAST(T2.WORLD_ID AS varchar(10)) || '  ' || T2.WORLD_NM as WORLD_NM from TBL_MY_WORLD T1, TBL_WORLD_INFO T2 WHERE T1.SERVER_TYPE = 0 AND T1.LOGIN_ID = p_login_id AND T1.WORLD_ID = T2.WORLD_ID AND T2.WORLD_NM != 'ALL' order by t1.WORLD_ID asc;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] my_workflow_insert
--   Warning: CURSOR logic detected - converted to PG cursor syntax

CREATE OR REPLACE FUNCTION my_workflow_insert(
    p_workflow_cd varchar(40)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_fetch_found boolean := true;
    v_login_id varchar(30);
    v_organization_id varchar(30);
    v_approval_stage_num integer;
    v_is_final varchar(3);
    xcur CURSOR FOR select login_id, organization_id, approval_stage_num, is_final  from TBL_APPROVAL_DEFAULT_STAGE group by login_id, organization_id, approval_stage_num, is_final;
BEGIN
    OPEN xcur;
    FETCH xcur INTO v_login_id, v_organization_id, v_approval_stage_num, v_is_final;
    v_fetch_found := FOUND;
    WHILE v_fetch_found LOOP
    insert into TBL_APPROVAL_DEFAULT_STAGE values(v_approval_stage_num, p_workflow_cd, v_login_id, v_is_final, v_organization_id, p_workflow_cd || '_' || v_organization_id);
    FETCH xcur INTO v_login_id, v_organization_id, v_approval_stage_num, v_is_final;
    v_fetch_found := FOUND;
    END LOOP;
    CLOSE xcur;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblMyWorldDA_SrchWorldServerStatus

CREATE OR REPLACE FUNCTION tblmyworldda_srchworldserverstatus(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_WORLD_CONCURRENT_INFO;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] my_world_insert
--   Warning: CURSOR logic detected - converted to PG cursor syntax

CREATE OR REPLACE FUNCTION my_world_insert(
    p_world_id varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_fetch_found boolean := true;
    v_user_id varchar(30);
    xcur CURSOR FOR select login_id from tbl_admin_user  where  is_deleted='Y' group by login_id;
BEGIN
    OPEN xcur;
    FETCH xcur INTO v_user_id;
    v_fetch_found := FOUND;
    WHILE v_fetch_found LOOP
    insert into TBL_MY_WORLD values(p_world_id, v_user_id, 0);
    FETCH xcur INTO v_user_id;
    v_fetch_found := FOUND;
    END LOOP;
    CLOSE xcur;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPCCopyDA_SrchList

CREATE OR REPLACE FUNCTION tblpccopyda_srchlist(
    p_status smallint,
    p_move_type smallint,
    p_view_count integer,
    p_top_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM  PCCOPY_ID,SRC_WORLD_ID, SRC_CHAR_ID,SRC_CHAR_NM,SRC_ACCOUNT_ID,SRC_ACCOUNT_NAME,SRC_CHAR_GENDER,SRC_CHAR_RACE,SRC_CHAR_CLASS,SRC_CHAR_LEV, TARGET_WORLD_ID, TARGET_CHAR_ID,TARGET_CHAR_NM,TARGET_ACCOUNT_ID,TARGET_ACCOUNT_NAME,TARGET_CHAR_GENDER,TARGET_CHAR_RACE,TARGET_CHAR_CLASS,TARGET_CHAR_LEV, STATUS,	MOVE_TYPE, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, TO_CHAR(movedate, 'YYYY-MM-DD HH24:MI:SS') movedate from tbl_pc_copy where status = p_status::integer and move_type=p_move_type and pccopy_id not in (SELECT  pccopy_id from tbl_pc_copy where status = p_status::integer and move_type=p_move_type order by pccopy_id desc LIMIT p_top_count) order by pccopy_id desc LIMIT p_view_count;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminGroupDA_SrchAllGroups

CREATE OR REPLACE FUNCTION tbladmingroupda_srchallgroups(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT GROUP_ID, GROUP_NM, IS_DELETED from TBL_ADMIN_GROUP order by group_nm asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPCCopyDA_SrchPCCopyListByStatusNType

CREATE OR REPLACE FUNCTION tblpccopyda_srchpccopylistbystatusntype(
    p_status integer,
    p_move_type integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* FROM	tbl_pc_copy  WHERE	status = p_status::integer and move_type=p_move_type;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminGroupDA_SrchGroupByGroupID

CREATE OR REPLACE FUNCTION tbladmingroupda_srchgroupbygroupid(
    p_group_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT group_id, group_nm, is_deleted from TBL_ADMIN_GROUP where group_id = p_group_id::integer;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblPollDA_PollSrch
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblpollda_pollsrch(
    p_poll_subject varchar(50),
    p_poll_search_id varchar(20),
    p_str_servers varchar(100),
    p_poll_status varchar(5),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_is_deleted varchar(2)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1500);
BEGIN
    v_sql := ' SELECT order_num, race, poll_level, poll_id, poll_title, IS_DELETED, poll_xml_filename, poll_servers, poll_cnt, poll_status, TO_CHAR(poll_start_date, ''YYYY-MM-DD HH24:MI:SS'') poll_start_date, TO_CHAR(poll_end_date, ''YYYY-MM-DD HH24:MI:SS'') poll_end_date, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' FROM tbl_poll ' || ' where IS_DELETED=''' || p_is_deleted || ''' and regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_poll_status != 'null' THEN
    v_sql := v_sql || ' and poll_status=''' || p_poll_status || '''  ';
    END IF;
    IF p_poll_search_id != '' THEN
    v_sql := v_sql || ' and poll_id=''' || p_poll_search_id || '''  ';
    END IF;
    IF p_poll_subject != 'null' THEN
    v_sql := v_sql || ' and poll_title like ''%' || p_poll_subject || '%''  ';
    END IF;
    IF p_str_servers != 'null' THEN
    v_sql := v_sql || ' and poll_servers like ''%' || p_str_servers || '%''  ';
    END IF;
    v_sql := v_sql || ' order by regdate desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAdminLogDAO_GMLog
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbladminlogdao_gmlog(
    p_tbl_name varchar(50),
    p_login_id varchar(30),
    p_admin_ip varchar(30),
    p_menu_id varchar(30),
    p_action_code varchar(30),
    p_log_info varchar(1000)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1300);
BEGIN
    v_sql := ' INSERT INTO ' || p_tbl_name || ' VALUES(''' || p_login_id || ''', ''' || p_admin_ip || ''', ''' || p_menu_id || ''', ''' || p_action_code || ''', CURRENT_TIMESTAMP, ''' || p_log_info || ''') ';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollDA_PollSrchByID

CREATE OR REPLACE FUNCTION tblpollda_pollsrchbyid(
    p_poll_Id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT poll_id, POLL_XML_CONTENTS, IS_DELETED, poll_title, poll_xml_filename, poll_servers, poll_cnt, poll_status, TO_CHAR(poll_start_date, 'YYYY-MM-DD HH24:MI:SS') poll_start_date, TO_CHAR(poll_end_date, 'YYYY-MM-DD HH24:MI:SS') poll_end_date, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate FROM tbl_poll where poll_id=p_poll_Id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminMenuDA_SrchAddedMenus

CREATE OR REPLACE FUNCTION tbladminmenuda_srchaddedmenus(
    p_group_id varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT MENU_ID, MENU_GROUP_CODE, MENU_CODE, MENU_DEPTH, MENU_URL, MENU_TARGET, MENU_IMG, IS_MENU from TBL_ADMIN_MENU where MENU_ID NOT IN (select MENU_ID from TBL_GROUP_FUNC WHERE GROUP_ID = p_group_id::integer) ORDER BY MENU_GROUP_CODE ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollDA_PollSrchWillBeDeletedList

CREATE OR REPLACE FUNCTION tblpollda_pollsrchwillbedeletedlist(
    p_poll_status varchar(3),
    p_poll_end_data varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT poll_id FROM tbl_poll where POLL_STATUS=p_poll_status and POLL_END_DATE<=p_poll_end_data;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminMenuDA_SrchAddedMenusForMyFunc

CREATE OR REPLACE FUNCTION tbladminmenuda_srchaddedmenusformyfunc(
    p_login_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT MENU_ID, MENU_GROUP_CODE, MENU_CODE, MENU_DEPTH, MENU_URL, MENU_TARGET, MENU_IMG, IS_MENU from TBL_ADMIN_MENU where MENU_ID NOT IN (select MENU_ID from TBL_MY_FUNC WHERE LOGIN_ID = p_login_id) ORDER BY MENU_GROUP_CODE ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollServerDA_CurUsingPollServerSrch

CREATE OR REPLACE FUNCTION tblpollserverda_curusingpollserversrch(
    p_poll_Id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT poll_id from tbl_poll_server where poll_id=p_poll_Id and (pub_status='ING' or pub_status='SUC');
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminMenuDA_SrchMenuIDByMenuCode

CREATE OR REPLACE FUNCTION tbladminmenuda_srchmenuidbymenucode(
    p_menu_code varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT menu_id from TBL_ADMIN_MENU where menu_code = p_menu_code;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollServerDA_PollDiff

CREATE OR REPLACE FUNCTION tblpollserverda_polldiff(
    p_cycle_min varchar(5),
    p_max_min varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.poll_id, t1.world_id, t1.pub_status, t1.RS_FILE_NAME, t1.poll_cnt, t1.start_date, t1.end_date, TO_CHAR(t1.gathering_date, 'YYYY-MM-DD HH24:MI:SS') gathering_date, t1.regdate from tbl_poll_server t1, tbl_poll t2 where t2.is_deleted='Y' and t1.poll_id=t2.poll_id and (t1.pub_status='ING' or t1.pub_status='STP' or t1.pub_status='COM') and (EXTRACT(EPOCH FROM (t1.end_date)::timestamp - (t1.gathering_date)::timestamp) / 60)::integer <= '' || p_cycle_min || '' and (EXTRACT(EPOCH FROM (end_date)::timestamp - (gathering_date)::timestamp) / 60)::integer >= '' || p_max_min || '';
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminMenuDA_SrchMenus

CREATE OR REPLACE FUNCTION tbladminmenuda_srchmenus(
    p_is_menu char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT MENU_ID, MENU_GROUP_CODE, MENU_CODE, MENU_DEPTH, MENU_URL, MENU_TARGET, MENU_IMG, IS_MENU from TBL_ADMIN_MENU ORDER BY MENU_GROUP_CODE ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollServerDA_PollServerSrchByDateandStatus

CREATE OR REPLACE FUNCTION tblpollserverda_pollserversrchbydateandstatus(
    p_cur_date varchar(30),
    p_pub_status varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.poll_id, t1.world_id, t1.pub_status, t1.RS_FILE_NAME, t1.poll_cnt, t1.start_date, t1.end_date, TO_CHAR(t1.gathering_date, 'YYYY-MM-DD HH24:MI:SS') gathering_date, t1.regdate from tbl_poll_server t1, tbl_poll t2 where t2.is_deleted='Y' and t1.poll_id=t2.poll_id and (t1.pub_status='ING' or t1.pub_status='STP' or t1.pub_status='' || p_pub_status || '') and t1.start_date <='' || p_cur_date || '' and t1.end_date >='' || p_cur_date || '';
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAdminMenuDA_SrchMyMenu
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbladminmenuda_srchmymenu(
    p_login_id varchar(30),
    p_is_menu char(1)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select * from ( ' || ' select T1.MENU_ID, T1.MENU_CODE, T1.MENU_DEPTH, T1.MENU_GROUP_CODE, T1.MENU_URL, T1.MENU_TARGET, T1.MENU_IMG ' || ' from TBL_ADMIN_MENU T1, TBL_GROUP_FUNC T2, TBL_ADMIN_GROUP T3, TBL_MY_GROUP T4 ' || ' where T1.IS_MENU = ''' || p_is_menu || ''' AND ' || ' (T1.MENU_ID = T2.MENU_ID AND T2.SEARCH_AUTH = ''Y'' ) AND ' || ' T2.GROUP_ID = T3.GROUP_ID AND ' || ' T3.GROUP_ID = T4.GROUP_ID AND	' || ' T4.LOGIN_ID = ''' || p_login_id || ''' ' || ' union ' || ' select T1.MENU_ID, T1.MENU_CODE, T1.MENU_DEPTH, T1.MENU_GROUP_CODE, T1.MENU_URL, T1.MENU_TARGET, T1.MENU_IMG ' || ' from TBL_ADMIN_MENU T1, TBL_MY_FUNC T5  ' || ' where T1.IS_MENU = ''' || p_is_menu || ''' AND ' || ' T1.MENU_ID = T5.MENU_ID and T5.LOGIN_ID = ''' || p_login_id || ''' AND T5.SEARCH_AUTH = ''Y'' ) T1 ' || ' ORDER BY T1.MENU_GROUP_CODE ASC ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollServerDA_PollServerSrchByPollID

CREATE OR REPLACE FUNCTION tblpollserverda_pollserversrchbypollid(
    p_poll_Id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT poll_id, world_id, pub_status, RS_FILE_NAME, poll_cnt, start_date, TO_CHAR(end_date, 'YYYY-MM-DD HH24:MI:SS') end_date, TO_CHAR(gathering_date, 'YYYY-MM-DD HH24:MI:SS') gathering_date, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate FROM TBL_POLL_SERVER where poll_id=p_poll_Id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAdminOptionsDA_SrchMyOptions
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbladminoptionsda_srchmyoptions(
    p_login_id varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select * from tbl_admin_options ' || ' where login_id = ''' || p_login_id || ''' ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPollServerDA_PollServerSrchByPollIDandStatus

CREATE OR REPLACE FUNCTION tblpollserverda_pollserversrchbypollidandstatus(
    p_poll_Id integer,
    p_pub_status varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * FROM TBL_POLL_SERVER where poll_id=p_poll_Id and pub_status=p_pub_status;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminOrganizationDA_SrchOrganization

CREATE OR REPLACE FUNCTION tbladminorganizationda_srchorganization(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT organization_id, organization_nm, organization_info FROM TBL_ADMIN_ORGANIZATION;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblPresetDA_SrchMyPreset
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblpresetda_srchmypreset(
    p_preset_nm varchar(50),
    p_login_id varchar(30),
    p_is_deleted varchar(2),
    p_is_shared varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' SELECT T1.PRESET_ID, T1.PRESET_NM, T1.IS_SHARED, T1.IS_DELETED, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, T2.LOGIN_NM, T2.LOGIN_ID, T2.IS_DELETED ' || ' FROM TBL_PRESET T1, TBL_ADMIN_USER T2 ' || ' WHERE	T1.LOGIN_ID = T2.LOGIN_ID ';
    IF p_login_id != 'null' THEN
    v_sql := v_sql || ' AND (T1.LOGIN_ID = ''' || p_login_id || ''' OR T1.IS_SHARED = ''' || p_is_shared || ''')';
    END IF;
    IF p_preset_nm != 'null' THEN
    v_sql := v_sql || ' AND T1.PRESET_NM like ''%' || p_preset_nm || '%''';
    END IF;
    IF p_is_deleted IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.IS_DELETED = ''' || p_is_deleted || '''';
    END IF;
    v_sql := v_sql || ' ORDER BY T1.REGDATE DESC';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminOrganizationDA_SrchOrganizationByID

CREATE OR REPLACE FUNCTION tbladminorganizationda_srchorganizationbyid(
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT organization_id, organization_nm, organization_info FROM TBL_ADMIN_ORGANIZATION where organization_id = p_organization_id::integer;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPresetDA_SrchPresetByID

CREATE OR REPLACE FUNCTION tblpresetda_srchpresetbyid(
    p_preset_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.PRESET_ID, T1.PRESET_NM, T1.IS_SHARED, T1.IS_DELETED, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, T1.LOGIN_ID, T2.LOGIN_NM, T2.IS_DELETED, T2.LOGIN_EMAIL, T2.ADMIN_ID FROM TBL_PRESET T1, TBL_ADMIN_USER T2 WHERE T1.LOGIN_ID = T2.LOGIN_ID AND T1.PRESET_ID = p_preset_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDA_InsertUserPwHistory

CREATE OR REPLACE FUNCTION tbladminuserda_insertuserpwhistory(
    p_login_id varchar(30),
    p_login_pw varchar(32)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    insert into TBL_ADMIN_USER_PW_HISTORY (LOGIN_ID, LOGIN_PW, REGDATE) values (p_login_id, p_login_pw, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPresetDA_SrchPresetByLoginIDandIsShared

CREATE OR REPLACE FUNCTION tblpresetda_srchpresetbyloginidandisshared(
    p_login_id varchar(30),
    p_is_shared varchar(2),
    p_is_deleted varchar(2)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT preset_id, preset_nm, is_shared, is_deleted, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, login_id from tbl_preset where (login_id = p_login_id or is_shared = p_is_shared) and is_deleted = p_is_deleted;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDA_SrchByAdminID

CREATE OR REPLACE FUNCTION tbladminuserda_srchbyadminid(
    p_admin_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT 	t1.admin_id, t1.login_id, t1.login_nm, t1.login_pw, t1.login_email, t1.is_deleted, t1.etc, TO_CHAR(t1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t1.PASSWORD_WRONG_CNT, t2.organization_id, t2.organization_nm, t2.organization_info from	tbl_admin_user t1, TBL_ADMIN_ORGANIZATION t2 where	admin_id = p_admin_id and t1.organization_id = t2.organization_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblPresetDA_SrchPresetByPresetorIDorNMorIsShared
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblpresetda_srchpresetbypresetoridornmorisshared(
    p_preset_nm varchar(50),
    p_login_id varchar(30),
    p_login_nm varchar(50),
    p_is_shared varchar(5),
    p_is_correct varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' SELECT T1.PRESET_ID, T1.PRESET_NM, T1.IS_SHARED, T1.IS_DELETED, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, T2.LOGIN_NM, T2.LOGIN_ID, T2.IS_DELETED ' || ' FROM TBL_PRESET T1, TBL_ADMIN_USER T2 ' || ' WHERE	T1.LOGIN_ID = T2.LOGIN_ID ';
    IF p_login_id != 'null' THEN
    IF p_is_correct IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.LOGIN_ID = ''' || p_login_id || '''';
    ELSE
    v_sql := v_sql || ' AND T1.LOGIN_ID like ''%' || p_login_id || '%''';
    END IF;
    END IF;
    IF p_login_nm != 'null' THEN
    IF p_is_correct IS NOT NULL THEN
    v_sql := v_sql || ' AND T2.LOGIN_NM = ''' || p_login_nm || '''';
    ELSE
    v_sql := v_sql || ' AND T2.LOGIN_NM like ''%' || p_login_nm || '%''';
    END IF;
    END IF;
    IF p_preset_nm != 'null' THEN
    v_sql := v_sql || ' AND T1.PRESET_NM = ''' || p_preset_nm || '''';
    END IF;
    IF p_is_shared IS NOT NULL THEN
    v_sql := v_sql || ' AND T1.IS_SHARED = ''' || p_is_shared || '''';
    END IF;
    v_sql := v_sql || ' ORDER BY T1.REGDATE DESC';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDA_SrchByLoginID

CREATE OR REPLACE FUNCTION tbladminuserda_srchbyloginid(
    p_login_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	ADMIN_ID, LOGIN_ID, LOGIN_PW, LOGIN_NM, LOGIN_EMAIL, ORGANIZATION_ID, IS_DELETED, REGDATE , (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (PWDATE)::timestamp) / 86400)::integer pwday, ADMIN_LEVEL, AUTH_UPDATE_DATE, PASSWORD_WRONG_CNT from	tbl_admin_user  where	login_id = p_login_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblPresetDAO_InsertPreset

CREATE OR REPLACE FUNCTION tblpresetdao_insertpreset(
    p_preset_id varchar(30),
    p_preset_nm varchar(50),
    p_is_shared varchar(2),
    p_login_id varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_PRESET VALUES(p_preset_id, p_preset_nm, p_is_shared, 'Y', CURRENT_TIMESTAMP, p_login_id);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDA_SrchByLoginIDandPW

CREATE OR REPLACE FUNCTION tbladminuserda_srchbyloginidandpw(
    p_login_id varchar(50),
    p_login_pw varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT admin_level, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (PWDATE)::timestamp) / 86400)::integer pwday, admin_id, login_id, login_nm, login_pw, login_email, is_deleted, organization_id, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate from tbl_admin_user  where is_deleted='Y'  and login_id = '' || p_login_id || '' and login_pw COLLATE KOREAN_WANSUNG_CS_AS = '' || p_login_pw || '';
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblQuestDA_SrchMyQuest

CREATE OR REPLACE FUNCTION tblquestda_srchmyquest(
    p_world_id varchar(5),
    p_char_id varchar(20),
    p_account_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_QUEST where world_id = p_world_id::integer and char_id = p_char_id::integer and account_id = p_account_id::integer order by quest_pk desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAdminUserDA_SrchGMByIDorNMorISDEL
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tbladminuserda_srchgmbyidornmorisdel(
    p_login_id varchar(30),
    p_login_nm varchar(50),
    p_is_deleted varchar(5),
    p_is_correct varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
    v_tmp integer;
BEGIN
    v_sql := ' SELECT T1.ADMIN_LEVEL, T2.ORGANIZATION_NM, T2.ORGANIZATION_ID, T1.ADMIN_ID, T1.LOGIN_ID, T1.LOGIN_PW, T1.LOGIN_NM, T1.LOGIN_EMAIL, T1.IS_DELETED, T1.ETC, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, TO_CHAR(T1.AUTH_UPDATE_DATE, ''YYYY-MM-DD HH24:MI:SS'') AUTH_UPDATE_DATE ' || ' FROM TBL_ADMIN_USER T1, TBL_ADMIN_ORGANIZATION T2 ' || ' WHERE T1.ORGANIZATION_ID = T2.ORGANIZATION_ID  ';
    v_tmp := 0;
    IF p_login_id != 'null' THEN
    IF p_is_correct != 'null' THEN
    v_sql := v_sql || ' AND LOGIN_ID = ''' || p_login_id || '''';
    ELSE
    v_sql := v_sql || ' AND LOGIN_ID like ''%' || p_login_id || '%''';
    END IF;
    v_tmp := 1;
    END IF;
    IF p_login_nm != 'null' THEN
    IF v_tmp = 1 THEN
    IF p_is_correct != 'null' THEN
    v_sql := v_sql || ' AND LOGIN_NM = ''' || p_login_nm || '''';
    ELSE
    v_sql := v_sql || ' AND LOGIN_NM like ''%' || p_login_nm || '%''';
    ELSE
    IF p_is_correct != 'null' THEN
    v_sql := v_sql || ' AND LOGIN_NM = ''' || p_login_nm || '''';
    ELSE
    v_sql := v_sql || ' AND LOGIN_NM like ''%' || p_login_nm || '%''';
    END IF;
    v_tmp := 1;
    END IF;
    END IF;
    IF p_is_deleted != 'null' THEN
    v_sql := v_sql || ' AND is_deleted = ''' || p_is_deleted || '''';
    END IF;
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblQuestDA_SrchMyQuestByReqID

CREATE OR REPLACE FUNCTION tblquestda_srchmyquestbyreqid(
    p_quest_req_id varchar(30),
    p_world_id varchar(5),
    p_char_id varchar(20),
    p_account_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_QUEST where quest_req_id = p_quest_req_id and world_id = p_world_id::integer and char_id = p_char_id::integer and account_id = p_account_id::integer;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDA_SrchRecentlyPasswordByLoginId

CREATE OR REPLACE FUNCTION tbladminuserda_srchrecentlypasswordbyloginid(
    p_login_id varchar(30),
    p_top_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM  ID, LOGIN_ID, LOGIN_PW, REGDATE FROM	TBL_ADMIN_USER_PW_HISTORY  WHERE	LOGIN_ID = p_login_id ORDER BY ID DESC LIMIT p_top_count;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblQuestDA_SrchQuest
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblquestda_srchquest(
    p_char_nm varchar(50),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_world_id varchar(3)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1500);
BEGIN
    v_sql := ' select t1.quest_pk, t1.quest_req_id, t1.quest_id, t1.quest_status, t1.quest_progress, t1.quest_branch, t1.char_id, t1.char_nm, t1.account_id, t1.request_type, t1.quest_req_info, t1.world_id, t1.communication_cd, TO_CHAR(t1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from tbl_quest t1 ' || ' where t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_char_nm != 'null' THEN
    v_sql := v_sql || ' and t1.char_nm=''' || p_char_nm || '''  ';
    END IF;
    IF p_world_id != 'null' THEN
    v_sql := v_sql || ' and t1.world_id=''' || p_world_id || '''  ';
    END IF;
    v_sql := v_sql || ' order by t1.regdate desc, t1.world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_CreateGM

CREATE OR REPLACE FUNCTION tbladminuserdao_creategm(
    p_login_id varchar(150),
    p_login_pw varchar(150),
    p_login_nm varchar(150),
    p_login_email varchar(170),
    p_organization_id varchar(50),
    p_is_deleted varchar(2),
    p_etc varchar(200),
    p_admin_level smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_ADMIN_USER (login_id, login_pw, login_nm, login_email, organization_id, is_deleted, etc, regdate, pwdate, admin_level, auth_update_date) VALUES(p_login_id, p_login_pw, p_login_nm, p_login_email,p_organization_id, p_is_deleted, p_etc, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, p_admin_level, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblSpecialGroupDA_SrchAccessibleFunc

CREATE OR REPLACE FUNCTION tblspecialgroupda_srchaccessiblefunc(
    p_login_id varchar(100),
    p_special_func_cd varchar(100)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) my_auth from tbl_admin_user t1, tbl_my_group t2, tbl_special_group t3, tbl_special_func t4 where t1.login_id = p_login_id and t1.login_id = t2.login_id and t2.group_id = t3.group_id and t3.special_func_id = t4.special_func_id and t4. special_func_cd = p_special_func_cd;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_UpdateGMState

CREATE OR REPLACE FUNCTION tbladminuserdao_updategmstate(
    p_admin_id varchar(10),
    p_is_deleted varchar(2)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET IS_DELETED = p_is_deleted, AUTH_UPDATE_DATE = CURRENT_TIMESTAMP WHERE ADMIN_ID = p_admin_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblSpecialGroupDA_SrchAddableFunc

CREATE OR REPLACE FUNCTION tblspecialgroupda_srchaddablefunc(
    p_group_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t3.menu_id, t3. menu_code, t3.menu_depth, t2.special_func_id, t2.special_func_cd, t2.special_func_desc from tbl_special_func t2, tbl_admin_menu t3 where t2.menu_id = t3.menu_id and t2.special_func_id not in (select special_func_id from tbl_special_group where group_id = p_group_id::integer) order by t3.menu_id asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_UpdateMyGM

CREATE OR REPLACE FUNCTION tbladminuserdao_updatemygm(
    p_admin_id varchar(10),
    p_login_pw varchar(150),
    p_login_email varchar(170),
    p_etc varchar(200)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET PWDATE=CURRENT_TIMESTAMP, login_pw = p_login_pw, login_email = p_login_email, etc = p_etc WHERE ADMIN_ID = p_admin_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblSpecialGroupDA_SrchAddedFunc

CREATE OR REPLACE FUNCTION tblspecialgroupda_srchaddedfunc(
    p_group_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t3.menu_id, t3. menu_code, t3.menu_depth, t2.special_func_id, t2.special_func_cd, t2.special_func_desc, t1.group_id, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate from tbl_special_group t1, tbl_special_func t2, tbl_admin_menu t3 where t1.special_func_id = t2.special_func_id and t2.menu_id = t3.menu_id and t1.group_id = p_group_id::integer order by t3.menu_id asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_UpdateMyGMForNoPassword

CREATE OR REPLACE FUNCTION tbladminuserdao_updatemygmfornopassword(
    p_admin_id varchar(10),
    p_login_email varchar(170),
    p_etc varchar(200)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET login_email = p_login_email, etc = p_etc WHERE ADMIN_ID = p_admin_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblStatisticsDA_SrchPollRS

CREATE OR REPLACE FUNCTION tblstatisticsda_srchpollrs(
    p_world_id varchar(5),
    p_poll_id varchar(15),
    p_to_date varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT WORLD_ID,POLL_ID,CHAR_ID,USER_ID,ACCOUNT_ID,ACCOUNT_NAME,CLASS,RACE,WORLD,XLOCATION,YLOCATION,ZLOCATION,LEV,TO_CHAR(ANSWER_TIME, 'YYYY-MM-DD HH24:MI:SS') ANSWER_TIME,ANSWER from TBL_STATISTICS_POLL where world_id = p_world_id::integer and poll_id='' || p_poll_id || '';
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_UpdatePasswordByLoginID

CREATE OR REPLACE FUNCTION tbladminuserdao_updatepasswordbyloginid(
    p_LOGIN_ID varchar(30),
    p_LOGIN_PW varchar(32)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_ADMIN_USER SET		LOGIN_PW = p_LOGIN_PW WHERE	LOGIN_ID = p_LOGIN_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblStatisticsScheduleDA_SrchReservedSchedule

CREATE OR REPLACE FUNCTION tblstatisticsscheduleda_srchreservedschedule(
    p_current_time varchar(30),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_statistics_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_STATISTICS_SCHEDULE where ((STATISTICS_TO >= p_current_time and STATISTICS_FROM <= p_current_time and PERIOD_HOUR = p_period_hour AND PERIOD_MIN = p_period_min) or (STATISTICS_TO >= p_current_time and STATISTICS_FROM <= p_current_time and statistics_repeat_min != 0) or (statistics_period = 'ONCE' and task_cd = 'BEF')) AND statistics_status = p_statistics_status and task_cd != 'TRA' order by regdate ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserDAO_UpdatePasswordWrongCnt

CREATE OR REPLACE FUNCTION tbladminuserdao_updatepasswordwrongcnt(
    p_LOGIN_ID varchar(30),
    p_PASSWORD_WRONG_CNT smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_ADMIN_USER SET		PASSWORD_WRONG_CNT = p_PASSWORD_WRONG_CNT WHERE	LOGIN_ID = p_LOGIN_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblStatisticsScheduleDA_SrchTransHistory

CREATE OR REPLACE FUNCTION tblstatisticsscheduleda_srchtranshistory(
    p_statistics_id varchar(30),
    p_cur_yyyymmdd varchar(8),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_task_cd varchar(30),
    p_statistics_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) sendable from TBL_STATISTICS_SCHEDULE t1, TBL_STATISTICS_HISTORY t2 where t1.statistics_id = t2.statistics_id and t1.statistics_id = p_statistics_id and t1.period_hour = p_period_hour and t1.period_min = p_period_min and (t1.task_cd = p_task_cd OR t1.task_cd = 'TRA') and t1.statistics_status = p_statistics_status and TO_CHAR(t2.regdate, 'YYYYMMDD') = p_cur_yyyymmdd;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblAdminUserHistoryDA_SrchHistory

CREATE OR REPLACE FUNCTION tbladminuserhistoryda_srchhistory(
    p_admin_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  T1.LOGIN_NM, T2.*, (SELECT LOGIN_NM FROM TBL_ADMIN_USER T3 WHERE T3.ADMIN_ID=T2.BY_ADMIN_ID) BY_LOGIN_NM FROM TBL_ADMIN_USER T1, TBL_ADMIN_USER_HISTORY T2 WHERE T1.ADMIN_ID = T2.ADMIN_ID AND (T2.ADMIN_ID=p_admin_id OR T2.BY_ADMIN_ID=p_admin_id) order by t2.regdate desc LIMIT 50;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblStatisticsWorldDA_SrchStatisticsWorld

CREATE OR REPLACE FUNCTION tblstatisticsworldda_srchstatisticsworld(
    p_statistics_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from tbl_statistics_world where statistics_id = p_statistics_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchAbyssCateEvent
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srchabysscateevent(
    p_world_id varchar(3),
    p_event_cate varchar(30),
    p_from_date varchar(30),
    p_to_date varchar(30),
    p_event_info varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select ALERT_EVENT_ID, WORLD_ID, EVENT_ID, EVENT_INFO, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from tbl_alert_event ' || ' where world_id=''' || p_world_id || ''' and event_cate=''' || p_event_cate || ''' and event_info like ''' || p_event_info || ''' and regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''   ' || ' order by alert_event_id desc LIMIT 1';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorkflowListDA_SrchAllWorkflow

CREATE OR REPLACE FUNCTION tblworkflowlistda_srchallworkflow(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_WORKFLOW_LIST;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchAbyssEvent
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srchabyssevent(
    p_world_id varchar(3),
    p_event_info varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(300);
BEGIN
    v_sql := ' select ALERT_EVENT_ID, WORLD_ID, EVENT_ID, EVENT_INFO, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from tbl_alert_event ' || ' where (event_id=213 or event_cate=''abyss'') and world_id=''' || p_world_id || ''' and event_info like ''' || p_event_info || '''  ' || ' order by alert_event_id desc LIMIT 100';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldInfoDA_SrchAllWorlds

CREATE OR REPLACE FUNCTION tblworldinfoda_srchallworlds(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_WORLD_INFO where WORLD_STATUS = 'Y' order by world_id asc;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchAbyssEventID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srchabysseventid(
    p_world_id varchar(3),
    p_event_id varchar(30),
    p_from_date varchar(30),
    p_to_date varchar(30),
    p_event_info varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(300);
BEGIN
    v_sql := ' select ALERT_EVENT_ID, WORLD_ID, EVENT_ID, EVENT_INFO, CAST(regdate AS double precision) regdate from tbl_alert_event ' || ' where world_id=''' || p_world_id || ''' and event_id=''' || p_event_id || ''' and event_info like ''' || p_event_info || ''' and regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''    LIMIT 1';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldInfoDA_SrchAllWorldsByType

CREATE OR REPLACE FUNCTION tblworldinfoda_srchallworldsbytype(
    p_server_type smallint
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* FROM	TBL_WORLD_INFO  WHERE	WORLD_STATUS = 'Y' AND		SERVER_TYPE = p_server_type ORDER BY world_id ASC;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchCurEvent
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srchcurevent(
    p_from_date varchar(30),
    p_to_date varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select ALERT_EVENT_ID, WORLD_ID, EVENT_ID, EVENT_CATE, GRP_CD, PRIORITY, EVENT_INFO, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate from TBL_ALERT_EVENT ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' order by priority desc  ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldInfoDA_SrchGameFTWorlds

CREATE OR REPLACE FUNCTION tblworldinfoda_srchgameftworlds(
    p_from_world_id varchar(3),
    p_to_world_id varchar(3)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.WORLD_ID, T1.WORLD_NM, T1.WORLD_DESC, T1.WORLD_STATUS, T2.DARK_USERS AS TOTAL_CON_USERS, T2.PC_STORE_LIGHT_USERS AS LIGHT_CHAR_COUNT, T2.PC_STORE_DARK_USERS AS DARK_CHAR_COUNT from tbl_world_info t1, TBL_GAME_WORLD_INFO t2 where t1.world_id=t2.world_id and t2.zone_id=0 and t1.world_status='Y' and t1.world_id between p_from_world_id and p_to_world_id order by t1.world_id asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchEventCount
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srcheventcount(
    p_is_popup char(1),
    p_from_date varchar(30),
    p_to_date varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(300);
BEGIN
    v_sql := ' select count(*) cnt from tbl_alert_event ' || ' where is_popup=''' || p_is_popup || ''' and regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldInfoDA_SrchGameWorlds

CREATE OR REPLACE FUNCTION tblworldinfoda_srchgameworlds(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.WORLD_ID, T1.WORLD_NM, T1.WORLD_DESC, T1.WORLD_STATUS, T2.npc_count AS TOTAL_CON_USERS, T2.world_type AS LIGHT_CHAR_COUNT, T2.channel_num AS DARK_CHAR_COUNT from tbl_world_info t1, TBL_GAME_WORLD_INFO t2 where t1.world_id=t2.world_id and t2.zone_id=0 and t1.world_status='Y' order by t1.world_id asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblAlertEventDA_SrchWorldsEvent
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblalerteventda_srchworldsevent(
    p_grp varchar(20),
    p_world_id varchar(400),
    p_prioritys varchar(100),
    p_event_cate varchar(200),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_event_ids varchar(300),
    p_all_servers varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(2000);
BEGIN
    v_sql := ' select ALERT_EVENT_ID, WORLD_ID, EVENT_ID, EVENT_CATE, GRP_CD, PRIORITY, EVENT_INFO, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_ALERT_EVENT ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_all_servers IS NOT NULL THEN
    v_sql := v_sql || ' and ( ' || p_world_id || ') ';
    END IF;
    IF p_prioritys != 'null' THEN
    v_sql := v_sql || ' and ( ' || p_prioritys || ') ';
    END IF;
    IF p_event_cate != 'null' THEN
    v_sql := v_sql || ' and ( ' || p_event_cate || ') ';
    END IF;
    IF p_event_ids != 'null' THEN
    v_sql := v_sql || ' and ( ' || p_event_ids || ') ';
    END IF;
    v_sql := v_sql || ' order by regdate desc, world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldServerInfoDA_SrchAllServerAddress

CREATE OR REPLACE FUNCTION tblworldserverinfoda_srchallserveraddress(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT server_nm, world_id, server_url from TBL_WORLD_SERVER_INFO;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalCharDA_SrchApprovalCharByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalcharda_srchapprovalcharbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_CHAR where approval_info_id = p_approval_info_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldServerInfoDA_SrchServerAddress

CREATE OR REPLACE FUNCTION tblworldserverinfoda_srchserveraddress(
    p_server_nm varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT server_nm, world_id, server_url from TBL_WORLD_SERVER_INFO where server_nm = p_server_nm;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalCharDA_SrchApprovalGuildByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalcharda_srchapprovalguildbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_GUILD where approval_info_id = p_approval_info_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldStatusInfoDA_SrchConcurrentUsersByServerNM

CREATE OR REPLACE FUNCTION tblworldstatusinfoda_srchconcurrentusersbyservernm(
    p_server_nm integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_WORLD_STATUS_INFO where server_nm = p_server_nm;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalDefaultStageDA_SrchByApprovalGroup

CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchbyapprovalgroup(
    p_approval_group varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_group, t1.approval_default_stage_id, t1.approval_stage_num, t1.workflow_cd, t1.login_id, t1.is_final, t1.organization_id, t2.login_nm from TBL_APPROVAL_DEFAULT_STAGE T1, TBL_ADMIN_USER T2 where t1.approval_group = p_approval_group and t1.login_id = t2.login_id order by t1.approval_stage_num asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblWorldStatusInfoDA_SrchPerfLog
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblworldstatusinfoda_srchperflog(
    p_world_id varchar(3),
    p_server_id varchar(3),
    p_view_count varchar(5),
    p_top_count varchar(5),
    p_from_date varchar(30),
    p_to_date varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(700);
    v_sql_etc varchar(200);
BEGIN
    v_sql_etc := ' world_id=''' || p_world_id || ''' and server_nm=''' || p_server_id || ''' and regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    v_sql := ' select top ' || p_view_count || ' world_id, server_nm, cpu_usage, free_phy_memory, process_memory, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, db_free ' || ' from TBL_WORLD_STATUS_INFO  ' || ' where world_status_info_id not in(select top ' || p_top_count || ' world_status_info_id from TBL_WORLD_STATUS_INFO where ' || v_sql_etc || ' order by world_status_info_id desc) ';
    v_sql := v_sql || ' and ' || v_sql_etc || ' order by world_status_info_id desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalDefaultStageDA_SrchByWorkflowCDandOrganizationID

CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchbyworkflowcdandorganizationid(
    p_workflow_cd varchar(30),
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_group, t1.approval_default_stage_id, t1.approval_stage_num, t1.workflow_cd, t1.login_id, t1.is_final, t1.organization_id, t2.login_nm from TBL_APPROVAL_DEFAULT_STAGE T1, TBL_ADMIN_USER T2 where t1.workflow_cd = p_workflow_cd and t1.organization_id = p_organization_id::integer and t1.login_id = t2.login_id order by t1.approval_stage_num asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblWorldStatusInfoDA_SrchServerMonitor

CREATE OR REPLACE FUNCTION tblworldstatusinfoda_srchservermonitor(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.DB_FREE, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (T1.REGDATE)::timestamp) / 60)::integer AS is_alive, T1.WORLD_ID, T1.SERVER_NM, T1.CONCURRENT_USERS, T2.WORLD_NM FROM TBL_WORLD_STATUS_INFO T1, TBL_WORLD_INFO T2 WHERE T1.WORLD_ID = T2.WORLD_ID AND T2.WORLD_STATUS='Y' ORDER BY T1.WORLD_ID ASC, T1.SERVER_NM ASC;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalDefaultStageDA_SrchMyButtonByApprovalGroup

CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchmybuttonbyapprovalgroup(
    p_login_id varchar(30),
    p_approval_group varchar(30),
    p_is_final char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT approval_default_stage_id from TBL_APPROVAL_DEFAULT_STAGE where approval_group=p_approval_group and login_id=p_login_id and is_final=p_is_final;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] XMLCodeDA_SrchXML
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION xmlcodeda_srchxml(
    p_xml_type varchar(10),
    p_xml_ver varchar(5),
    p_xml_name varchar(50),
    p_xml_id varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select * ' || ' from xml_code  where xml_type = ''' || p_xml_type || ''' ';
    IF p_xml_ver != 'null' THEN
    v_sql := v_sql || ' and ( xml_ver=''' || p_xml_ver || ''') ';
    END IF;
    IF p_xml_name != 'null' THEN
    v_sql := v_sql || ' and ( xml_name like ''%' || p_xml_name || '%'') ';
    END IF;
    IF p_xml_id != 'null' THEN
    v_sql := v_sql || ' and ( xml_id=''' || p_xml_id || ''') ';
    END IF;
    v_sql := v_sql || ' order by xml_name asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalDefaultStageDA_SrchMyStage

CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchmystage(
    p_login_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  approval_stage_num from TBL_APPROVAL_DEFAULT_STAGE where login_id=p_login_id LIMIT 1;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalDefaultStageDA_SrchMyStageNumByWorkflowCDandOrganizationID

CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchmystagenumbyworkflowcdandorganizationid(
    p_login_id varchar(30),
    p_workflow_cd varchar(30),
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT approval_stage_num from TBL_APPROVAL_DEFAULT_STAGE where workflow_cd = p_workflow_cd and organization_id = p_organization_id::integer and login_id = p_login_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalAnimationByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalanimationbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	approval_animation_id, approval_info_id, animation_id, animation_type, expire_time, approval_type FROM	TBL_APPROVAL_ANIMATION  WHERE	approval_info_id = p_approval_info_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalCancel

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalcancel(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT approval_info_id from TBL_APPROVAL_INFO where approval_info_id = p_approval_info_id and approval_checkinout_status='' and approval_status!='CANCELED' and approval_status!='DEFERRED' and approval_status!='DENIED' and approval_status!='COMPLETION';
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalHistoryByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalhistorybyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_history_id, t1.approval_info_id, t1.login_id, t1.approval_status, t1.approval_stage_num, t1.approval_history_info, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.login_nm from TBL_APPROVAL_HISTORY t1, TBL_ADMIN_USER t2 where t1.login_id = t2.login_id and approval_info_id = p_approval_info_id order by t1.approval_history_id asc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalInfo

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalinfo(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_INFO where  approval_info_id = p_approval_info_id;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalMailByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalmailbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  t1.approval_history_id, t1.approval_info_id, t1.login_id, t1.approval_status, t1.approval_stage_num, t1.approval_history_info, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.login_nm, t2.login_email, T3.APPROVAL_TYPE from TBL_APPROVAL_HISTORY t1, TBL_ADMIN_USER t2, TBL_APPROVAL_INFO t3 where t1.login_id = t2.login_id and t1.approval_info_id = t3.approval_info_id and t1.approval_info_id = p_approval_info_id order by t1.APPROVAL_HISTORY_ID desc LIMIT 2;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalPetByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalpetbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_PET where approval_info_id = p_approval_info_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalSocialByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovalsocialbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_SOCIAL where approval_info_id = p_approval_info_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchApprovalTask

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchapprovaltask(
    p_communication_cd varchar(30),
    p_approval_status varchar(30),
    p_approval_checkinout_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_type, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_checkinout_status, t1.approval_stage_num, t1.communication_cd from TBL_APPROVAL_INFO t1 where t1.communication_cd = p_communication_cd and t1.approval_status = p_approval_status and t1.approval_checkinout_status = p_approval_checkinout_status;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblApprovalInfoDA_SrchMyCompletionDoc
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchmycompletiondoc(
    p_login_id varchar(30),
    p_approval_status varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_char_nm varchar(50),
    p_account_nm varchar(50),
    p_workflow_cd varchar(50),
    p_world_id varchar(5),
    p_is_paid varchar(5),
    p_doc_type varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1300);
BEGIN
    v_sql := 'select T1.DOC_TYPE, T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE, t1.approval_checkinout_nm, t1.APPROVAL_CHECKINOUT_REGDATE, t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_stage_num, t3.workflow_nm, t4.login_nm ' || ' from TBL_APPROVAL_INFO t1, TBL_APPROVAL_HISTORY t2, tbl_workflow_list t3, tbl_admin_user t4 ' || ' where t1.approval_info_id = t2.approval_info_id and ' || ' t1.login_id = t4.login_id and  ' || ' t2.login_id = ''' || p_login_id || ''' and  ' || ' t1.approval_status = ''' || p_approval_status || ''' and  ' || ' t2.approval_status = ''' || p_approval_status || ''' and  ' || ' t3.workflow_cd = t1.workflow_cd and ' || ' t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || ' and t1.world_id = ''' || p_world_id || '''';
    ELSE
    v_sql := v_sql || ' and t1.world_id in (select world_id from TBL_MY_WORLD where server_type=1 and login_id=''' || p_login_id || ''')';
    END IF;
    IF p_is_paid IS NOT NULL THEN
    v_sql := v_sql || ' and t1.is_paid = ''' || p_is_paid || '''';
    END IF;
    IF p_doc_type IS NOT NULL THEN
    v_sql := v_sql || ' and t1.doc_type = ''' || p_doc_type || '''';
    END IF;
    IF p_char_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_char_nm = ''' || p_char_nm || '''';
    END IF;
    IF p_account_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_account_nm = ''' || p_account_nm || '''';
    END IF;
    IF p_workflow_cd <> 'null' THEN
    v_sql := v_sql || ' and t1.workflow_cd = ''' || p_workflow_cd || '''';
    END IF;
    v_sql := v_sql || ' order by t1.regdate desc ';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] Log_TblGameServerInfo_UpdateServerstatus

CREATE OR REPLACE FUNCTION log_tblgameserverinfo_updateserverstatus(
    p_server_status smallint,
    p_world_id smallint,
    p_server_id smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_GAME_SERVER_INFO SET		SERVER_STATUS = p_server_status, REGDATE = CURRENT_TIMESTAMP WHERE	WORLD_ID = p_world_id::integer and SERVER_ID = p_server_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblApprovalInfoDA_SrchMyDoc
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchmydoc(
    p_login_id varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_char_nm varchar(50),
    p_account_nm varchar(50),
    p_workflow_cd varchar(50),
    p_approval_status varchar(50),
    p_is_error varchar(5),
    p_world_id varchar(5),
    p_is_paid varchar(5),
    p_doc_type varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select T1.DOC_TYPE, T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE, t1.approval_checkinout_nm, TO_CHAR(T1.APPROVAL_CHECKINOUT_REGDATE, ''YYYY-MM-DD HH24:MI:SS'') APPROVAL_CHECKINOUT_REGDATE , t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_stage_num, t3.workflow_nm, t4.login_nm ' || ' from TBL_APPROVAL_INFO t1, tbl_workflow_list t3, tbl_admin_user t4 ' || ' where  ' || ' t1.login_id = t4.login_id and ' || ' t1.workflow_cd = t3.workflow_cd and ' || ' t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_login_id <> 'null' THEN
    v_sql := v_sql || ' and t4.login_nm = ''' || p_login_id || '''';
    END IF;
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || ' and t1.world_id = ''' || p_world_id || '''';
    END IF;
    IF p_is_paid IS NOT NULL THEN
    v_sql := v_sql || ' and t1.is_paid = ''' || p_is_paid || '''';
    END IF;
    IF p_doc_type IS NOT NULL THEN
    v_sql := v_sql || ' and t1.doc_type = ''' || p_doc_type || '''';
    END IF;
    IF p_char_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_char_nm = ''' || p_char_nm || '''';
    END IF;
    IF p_account_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_account_nm = ''' || p_account_nm || '''';
    END IF;
    IF p_workflow_cd <> 'null' THEN
    v_sql := v_sql || ' and t1.workflow_cd = ''' || p_workflow_cd || '''';
    END IF;
    IF p_approval_status IS NOT NULL THEN
    v_sql := v_sql || ' and t1.approval_status = ''' || p_approval_status || '''';
    END IF;
    IF p_is_error IS NOT NULL THEN
    v_sql := v_sql || ' and (t1.approval_status =''COMPLETION'' and T1.COMMUNICATION_CD != ''SUC''  ) ';
    END IF;
    v_sql := v_sql || ' order by t1.regdate desc ';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblApprovalInfoDA_SrchMyProgressByLoginID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchmyprogressbyloginid(
    p_login_id varchar(30),
    p_approval_status varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_char_nm varchar(50),
    p_account_nm varchar(50),
    p_workflow_cd varchar(50),
    p_world_id varchar(5),
    p_is_paid varchar(5),
    p_doc_type varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(2000);
BEGIN
    v_sql := ' select T1.DOC_TYPE, T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE, t1.approval_checkinout_nm, t1.APPROVAL_CHECKINOUT_REGDATE, t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_stage_num, t3.workflow_nm, t4.login_nm ' || ' from TBL_APPROVAL_INFO t1, TBL_APPROVAL_DEFAULT_STAGE t2, tbl_workflow_list t3, tbl_admin_user t4 ' || ' where t1.login_id != ''' || p_login_id || ''' and ' || ' t1.approval_group = t2.approval_group and  ' || ' (t2.approval_stage_num-1) = t1.approval_stage_num and  ' || ' t1.login_id = t4.login_id and  ' || ' t2.login_id = ''' || p_login_id || ''' and  ' || ' t3.workflow_cd = t2.workflow_cd and ' || ' (t1.approval_status = ''' || p_approval_status || ''' or t1.approval_status = ''APPROVAL_RETURN'' ) and ' || ' t1.approval_status != ''DENIED'' and ' || ' t1.approval_status != ''CANCELED'' and ' || ' t1.approval_status != ''DEFERRED'' and ' || ' t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' and ' || ' (t1.approval_checkinout_status = '''' or (t1.approval_checkinout_id=''' || p_login_id || ''' and t1.approval_checkinout_status = ''Y'')) ';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || ' and t1.world_id = ''' || p_world_id || '''';
    ELSE
    v_sql := v_sql || ' and t1.world_id in (select world_id from TBL_MY_WORLD where server_type=1 and login_id=''' || p_login_id || ''')';
    END IF;
    IF p_is_paid IS NOT NULL THEN
    v_sql := v_sql || ' and t1.is_paid = ''' || p_is_paid || '''';
    END IF;
    IF p_doc_type IS NOT NULL THEN
    v_sql := v_sql || ' and t1.doc_type = ''' || p_doc_type || '''';
    END IF;
    IF p_char_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_char_nm = ''' || p_char_nm || '''';
    END IF;
    IF p_account_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_account_nm = ''' || p_account_nm || '''';
    END IF;
    IF p_workflow_cd <> 'null' THEN
    v_sql := v_sql || ' and t1.workflow_cd = ''' || p_workflow_cd || '''';
    END IF;
    v_sql := v_sql || ' order by t1.APPROVAL_CHECKINOUT_REGDATE desc ';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] Log_TblWorldStatusInfo_InsertServerinfo

CREATE OR REPLACE FUNCTION log_tblworldstatusinfo_insertserverinfo(
    p_world_id integer,
    p_server_nm integer,
    p_cpu_usage integer,
    p_free_phy_memory varchar(20),
    p_process_memory varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_WORLD_STATUS_INFO (WORLD_ID, SERVER_NM, CONCURRENT_USERS, CPU_USAGE, FREE_PHY_MEMORY, PROCESS_MEMORY, DB_FREE, REGDATE) VALUES (p_world_id, p_server_nm, 1, p_cpu_usage, p_free_phy_memory, p_process_memory, 1, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblApprovalInfoDA_SrchMyReferenceDoc
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchmyreferencedoc(
    p_login_id varchar(30),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_char_nm varchar(50),
    p_account_nm varchar(50),
    p_workflow_cd varchar(50),
    p_world_id varchar(5),
    p_is_paid varchar(5),
    p_doc_type varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select T1.DOC_TYPE, T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE, t1.approval_checkinout_nm, t1.APPROVAL_CHECKINOUT_REGDATE, t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_stage_num, t3.workflow_nm, t4.login_nm ' || ' from TBL_APPROVAL_INFO t1, TBL_APPROVAL_HISTORY t2, tbl_workflow_list t3, tbl_admin_user t4 ' || ' where t1.approval_info_id = t2.approval_info_id and ' || ' t1.login_id = t4.login_id and  ' || ' t2.login_id = ''' || p_login_id || ''' and  ' || ' t3.workflow_cd = t1.workflow_cd and ' || ' t1.regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_world_id <> 'null' THEN
    v_sql := v_sql || ' and t1.world_id = ''' || p_world_id || '''';
    ELSE
    v_sql := v_sql || ' and t1.world_id in (select world_id from TBL_MY_WORLD where server_type=1 and login_id=''' || p_login_id || ''')';
    END IF;
    IF p_is_paid IS NOT NULL THEN
    v_sql := v_sql || ' and t1.is_paid = ''' || p_is_paid || '''';
    END IF;
    IF p_doc_type IS NOT NULL THEN
    v_sql := v_sql || ' and t1.doc_type = ''' || p_doc_type || '''';
    END IF;
    IF p_char_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_char_nm = ''' || p_char_nm || '''';
    END IF;
    IF p_account_nm <> 'null' THEN
    v_sql := v_sql || ' and t1.approval_account_nm = ''' || p_account_nm || '''';
    END IF;
    IF p_workflow_cd <> 'null' THEN
    v_sql := v_sql || ' and t1.workflow_cd = ''' || p_workflow_cd || '''';
    END IF;
    v_sql := v_sql || ' order by t1.regdate desc ';
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] Log_TblGameWorldInfo_UpdateMainStatus

CREATE OR REPLACE FUNCTION log_tblgameworldinfo_updatemainstatus(
    p_light_users integer,
    p_dark_users integer,
    p_npc_count integer,
    p_pc_store_light_users integer,
    p_pc_store_dark_users integer,
    p_world_id smallint,
    p_zone_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_GAME_WORLD_INFO SET		LIGHT_USERS = p_light_users , DARK_USERS = p_dark_users , NPC_COUNT = p_npc_count , PC_STORE_LIGHT_USERS = p_pc_store_light_users , PC_STORE_DARK_USERS = p_pc_store_dark_users , REGDATE = CURRENT_TIMESTAMP WHERE	WORLD_ID = p_world_id::integer and ZONE_ID = p_zone_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchQinaAddDelDoc

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchqinaadddeldoc(
    p_char_id integer,
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_checkinout_status, t3.login_nm,t1.approval_info_id,t1.approval_stage_num,t1.approval_status,t1.approval_type,t1.APPROVAL_GROUP, t1.communication_cd, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.* from TBL_APPROVAL_INFO t1, TBL_APPROVAL_ITEM t2, tbl_admin_user t3, TBL_APPROVAL_HISTORY t4 where t1.approval_info_id=t2.approval_info_id and t1.approval_info_id=t4.approval_info_id and t4.approval_stage_num=3 and t1.login_id=t3.login_id and t2.approval_type!='GRQ_ITEMMOVE' and t1.approval_char_id=p_char_id and t1.world_id = p_world_id::integer and t1.approval_status='COMPLETION' and t2.item_id = 182400001 order by t1.regdate desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] Log_TblGameWorldInfo_UpdateTotalMainStatus

CREATE OR REPLACE FUNCTION log_tblgameworldinfo_updatetotalmainstatus(
    p_light_users integer,
    p_dark_users integer,
    p_npc_count integer,
    p_pc_store_light_users integer,
    p_world_id smallint,
    p_zone_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_GAME_WORLD_INFO SET		LIGHT_USERS = p_light_users , DARK_USERS = p_dark_users , NPC_COUNT = p_npc_count , PC_STORE_LIGHT_USERS = p_pc_store_light_users , REGDATE = CURRENT_TIMESTAMP WHERE	WORLD_ID = p_world_id::integer and ZONE_ID = p_zone_id::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchQinaMoveDoc

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchqinamovedoc(
    p_char_id integer,
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_checkinout_status, t3.login_nm,t1.approval_info_id,t1.approval_stage_num,t1.approval_status,t1.approval_type, t1.APPROVAL_GROUP, t1.communication_cd, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, TO_CHAR(T4.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.* from TBL_APPROVAL_INFO t1, TBL_APPROVAL_ITEM t2, tbl_admin_user t3, TBL_APPROVAL_HISTORY t4 where t1.approval_info_id=t2.approval_info_id and t1.approval_info_id=t4.approval_info_id and t4.approval_stage_num=3 and t1.login_id=t3.login_id and t2.approval_type='GRQ_ITEMMOVE' and t2.target_char_id=p_char_id and t1.world_id = p_world_id::integer and t1.approval_status='COMPLETION' and t2.item_id = 182400001 order by t1.regdate desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalInfoDA_SrchUserDoc

CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchuserdoc(
    p_account_id varchar(50),
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.DOC_TYPE, (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (T1.regdate)::timestamp) / 86400)::integer AS day_diff, T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE, t1.approval_checkinout_nm, TO_CHAR(T1.APPROVAL_CHECKINOUT_REGDATE, 'YYYY-MM-DD HH24:MI:SS') APPROVAL_CHECKINOUT_REGDATE , t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group, TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm, t1.approval_account_id, t1.approval_account_nm, t1.approval_info, t1.login_id, t1.approval_status, t1.approval_stage_num, t3.workflow_nm, t4.login_nm from TBL_APPROVAL_INFO t1, tbl_workflow_list t3, tbl_admin_user t4 where t1.login_id = t4.login_id and t1.workflow_cd = t3.workflow_cd and t1.approval_account_id = p_account_id and t1.world_id = p_world_id::integer order by t1.regdate desc;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalItemDA_SrchByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalitemda_srchbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	EXPIRED_TIME, ITEM_PKG_CNT, approval_item_id, approval_info_id, item_id, db_item_id, item_cnt, TARGET_WORLD_ID, TARGET_CHAR_ID, TARGET_CHAR_NM, TARGET_ACCOUNT_ID, TARGET_ACCOUNT_NM, item_enchant, SLOT_ID, SLOT, SOUL_BOUND, SKIN_NAME_ID, option_count, DYE_INFO, PROC_TOOL_NAMEID, PRODUCER, is_stackable, item_deposit, COMPOUND_TYPE, SEAL_STATE, SEAL_EXPIRED_TIME, CHARGE_POINT, COALESCE(EXPIRE_SKIN_TIME,0) as EXPIRE_SKIN_TIME , COALESCE(EXPIRE_DYE_TIME,0) as EXPIRE_DYE_TIME, COALESCE(RANDOM_OPTION,0) as RANDOM_OPTION , STAT_ENCHANT_NAME0, STAT_ENCHANT_NAME1, STAT_ENCHANT_NAME2, STAT_ENCHANT_NAME3, STAT_ENCHANT_NAME4, STAT_ENCHANT_NAME5, COALESCE(LIMIT_ENCHANT_COUNT,0) as LIMIT_ENCHANT_COUNT , REIDENTIFY_COUNT, POLISH_NAME_ID, RANDOM_ID, POLISH_POINT , FREETRADESTATE, AUTHORIZE_COUNT, VANISH_POINT , ATTRIBUTE1, ATTRIBUTE1VALUE, ATTRIBUTE2, ATTRIBUTE2VALUE, ATTRIBUTE3, ATTRIBUTE3VALUE, ATTRIBUTE4, ATTRIBUTE4VALUE, ATTRIBUTE5, ATTRIBUTE5VALUE, ATTRIBUTE6, ATTRIBUTE6VALUE from	TBL_APPROVAL_ITEM where	approval_info_id = p_approval_info_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalItemDA_SrchByApprovalInfoIDandType

CREATE OR REPLACE FUNCTION tblapprovalitemda_srchbyapprovalinfoidandtype(
    p_approval_info_id varchar(30),
    p_approval_type varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	EXPIRED_TIME, ITEM_PKG_CNT, approval_item_id, approval_info_id, item_id, db_item_id, item_cnt , TARGET_WORLD_ID, TARGET_CHAR_ID, TARGET_CHAR_NM, TARGET_ACCOUNT_ID, TARGET_ACCOUNT_NM , item_enchant, SLOT_ID, SLOT, SOUL_BOUND, SKIN_NAME_ID , option_count, DYE_INFO, PROC_TOOL_NAMEID, PRODUCER, is_stackable, item_deposit, COMPOUND_TYPE , SEAL_STATE, SEAL_EXPIRED_TIME, CHARGE_POINT , COALESCE(EXPIRE_SKIN_TIME,0) as EXPIRE_SKIN_TIME, COALESCE(EXPIRE_DYE_TIME,0) as EXPIRE_DYE_TIME , COALESCE(RANDOM_OPTION,0) as RANDOM_OPTION , STAT_ENCHANT_NAME0, STAT_ENCHANT_NAME1, STAT_ENCHANT_NAME2, STAT_ENCHANT_NAME3, STAT_ENCHANT_NAME4, STAT_ENCHANT_NAME5, COALESCE(LIMIT_ENCHANT_COUNT,0) as LIMIT_ENCHANT_COUNT , REIDENTIFY_COUNT, POLISH_NAME_ID, RANDOM_ID, POLISH_POINT , FREETRADESTATE, AUTHORIZE_COUNT, VANISH_POINT , ATTRIBUTE1, ATTRIBUTE1VALUE, ATTRIBUTE2, ATTRIBUTE2VALUE, ATTRIBUTE3, ATTRIBUTE3VALUE, ATTRIBUTE4, ATTRIBUTE4VALUE, ATTRIBUTE5, ATTRIBUTE5VALUE, ATTRIBUTE6, ATTRIBUTE6VALUE from	TBL_APPROVAL_ITEM where	approval_info_id = p_approval_info_id and approval_type = p_approval_type;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblApprovalItemDA_SrchStackableByApprovalInfoID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblapprovalitemda_srchstackablebyapprovalinfoid(
    p_approval_info_id varchar(30),
    p_approval_type varchar(30),
    p_is_stackable char(1)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(4000);
BEGIN
    v_sql := 'SELECT	expired_time, item_pkg_cnt, approval_item_id, approval_info_id, item_id, db_item_id, item_cnt ' || ' , target_world_id, target_char_id, target_char_nm, target_account_id, target_account_nm ' || ' , item_enchant, slot_id, slot, soul_bound, skin_name_id ' || ' , option_count, dye_info, proc_tool_nameid, producer ' || ' , is_stackable, item_deposit, compound_type, seal_state, seal_expired_time ' || ' , COALESCE(CHARGE_POINT,0) as CHARGE_POINT, COALESCE(EXPIRE_SKIN_TIME,0) as EXPIRE_SKIN_TIME, COALESCE(EXPIRE_DYE_TIME,0) as EXPIRE_DYE_TIME, COALESCE(RANDOM_OPTION,0) as RANDOM_OPTION ' || ' , STAT_ENCHANT_NAME0, STAT_ENCHANT_NAME1, STAT_ENCHANT_NAME2, STAT_ENCHANT_NAME3, STAT_ENCHANT_NAME4, STAT_ENCHANT_NAME5, COALESCE(LIMIT_ENCHANT_COUNT,0) as LIMIT_ENCHANT_COUNT ' || ' , REIDENTIFY_COUNT, POLISH_NAME_ID, RANDOM_ID, POLISH_POINT ' || ' , FREETRADESTATE, AUTHORIZE_COUNT, VANISH_POINT ' || ' , ATTRIBUTE1, ATTRIBUTE1VALUE, ATTRIBUTE2, ATTRIBUTE2VALUE, ATTRIBUTE3, ATTRIBUTE3VALUE, ATTRIBUTE4, ATTRIBUTE4VALUE, ATTRIBUTE5, ATTRIBUTE5VALUE, ATTRIBUTE6, ATTRIBUTE6VALUE ' || ' from	TBL_APPROVAL_ITEM ' || ' where	approval_info_id = ''' || p_approval_info_id || ''' and approval_type=''' || p_approval_type || ''' ';
    IF p_is_stackable = '' THEN
    v_sql := v_sql || ' and is_stackable=1 ';
    END IF;
    IF p_is_stackable = 'Y' THEN
    v_sql := v_sql || ' and is_stackable!=1 ';
    END IF;
    EXECUTE v_sql;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblApprovalSkillDA_SrchByApprovalInfoID

CREATE OR REPLACE FUNCTION tblapprovalskillda_srchbyapprovalinfoid(
    p_approval_info_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from TBL_APPROVAL_SKILL where approval_info_id = p_approval_info_id order by approval_type asc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBotPointRankingDA_SrchAccountPunish

CREATE OR REPLACE FUNCTION tblbotpointrankingda_srchaccountpunish(
    p_punish_group_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	punish_id, punish_group_id, punish_account_id, punish_account_name, punish_code, reg_login_id, reg_login_nm, reg_date, reg_date_str FROM	TBL_BOT_ACCOUNT_PUNISH  WHERE	punish_group_id = p_punish_group_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBotPointRankingDA_SrchAccountPunishHistory

CREATE OR REPLACE FUNCTION tblbotpointrankingda_srchaccountpunishhistory(
    p_date_from varchar(16),
    p_date_to varchar(16)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	punish_id, punish_group_id, punish_account_id, punish_account_name, punish_code, reg_login_id, reg_login_nm, reg_date, reg_date_str FROM	TBL_BOT_ACCOUNT_PUNISH  WHERE	reg_date BETWEEN p_date_from AND p_date_to ORDER BY reg_date_str DESC, punish_group_id, punish_account_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBotPointRankingDA_SrchAccountPunishHistoryGroup

CREATE OR REPLACE FUNCTION tblbotpointrankingda_srchaccountpunishhistorygroup(
    p_date_from varchar(16),
    p_date_to varchar(16)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	MAX(reg_date_str) AS reg_date_str, punish_group_id, punish_code, sum(1) AS account_count, reg_login_id, reg_login_nm FROM	TBL_BOT_ACCOUNT_PUNISH  WHERE	reg_date_str BETWEEN p_date_from AND p_date_to GROUP BY punish_group_id, punish_code, reg_login_id, reg_login_nm ORDER BY reg_date_str DESC;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblBotPointRankingDA_SrchBotPointRanking
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblbotpointrankingda_srchbotpointranking(
    p_world_id varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select row_number() over (order by bot_point desc ) as tot_ranking , *  ' || ' from TBL_BOT_POINT_RANKING  LIMIT 100';
    IF p_world_id != 'null' THEN
    v_sql := v_sql || ' where world_id=''' || p_world_id || ''' ';
    END IF;
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBotPointRankingDAO_InsertAccountPunish

CREATE OR REPLACE FUNCTION tblbotpointrankingdao_insertaccountpunish(
    p_punish_group_id varchar(20),
    p_punish_account_id integer,
    p_punish_account_name varchar(20),
    p_punish_code integer,
    p_punished_char_count integer,
    p_reg_login_id varchar(20),
    p_reg_login_nm varchar(20)
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    INSERT INTO TBL_BOT_ACCOUNT_PUNISH ( punish_group_id, punish_account_id, punish_account_name, punish_code, punished_char_count, reg_login_id, reg_login_nm, reg_date, reg_date_str ) VALUES ( p_punish_group_id, p_punish_account_id, p_punish_account_name, p_punish_code, p_punished_char_count, p_reg_login_id, p_reg_login_nm, CURRENT_TIMESTAMP, CAST(CURRENT_TIMESTAMP AS varchar(19)) );
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    RETURN v_rowcount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDA_SrchSchedule

CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchschedule(
    p_DATE varchar(20),
    p_COMMUNICATION_CD varchar(5) DEFAULT NULL
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    IF (p_COMMUNICATION_CD IS NULL) THEN
    RETURN QUERY SELECT	ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE FROM	TBL_BUILDER_COMMAND_SCHEDULE  WHERE	SCHEDULE_DATE = binary(p_DATE) AND		REPEAT_TYPE = 'ONCE';
    ELSE
    RETURN QUERY SELECT	ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE FROM	TBL_BUILDER_COMMAND_SCHEDULE  WHERE	SCHEDULE_DATE = binary(p_DATE) AND		COMMUNICATION_CD = p_COMMUNICATION_CD AND		REPEAT_TYPE = 'ONCE';
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDA_SrchScheduleByDate

CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchschedulebydate(
    p_DATEFROM varchar(20),
    p_DATETO varchar(20),
    p_COMMUNICATION_CD varchar(5) DEFAULT NULL
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    IF (p_COMMUNICATION_CD IS NULL) THEN
    RETURN QUERY SELECT	ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE FROM	TBL_BUILDER_COMMAND_SCHEDULE  WHERE	SCHEDULE_DATE BETWEEN binary(p_DATEFROM) AND binary(p_DATETO) ORDER BY ID DESC;
    ELSE
    RETURN QUERY SELECT	ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE FROM	TBL_BUILDER_COMMAND_SCHEDULE  WHERE	SCHEDULE_DATE BETWEEN binary(p_DATEFROM) AND binary(p_DATETO) AND		COMMUNICATION_CD = p_COMMUNICATION_CD ORDER BY ID DESC;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDA_SrchScheduleById

CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchschedulebyid(
    p_ID integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE FROM	TBL_BUILDER_COMMAND_SCHEDULE  WHERE	ID = p_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDA_SrchWorldById

CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchworldbyid(
    p_COMMAND_SCHEDULE_ID integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	COMMAND_SCHEDULE_ID, WORLD_ID, COMMUNICATION_CD, EXECUTE_DATE FROM	TBL_BUILDER_COMMAND_WORLD  WHERE	COMMAND_SCHEDULE_ID	= p_COMMAND_SCHEDULE_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_DeleteSchedule

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_deleteschedule(
    p_ID integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM TBL_BUILDER_COMMAND_SCHEDULE WHERE	ID = p_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_DeleteWorld

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_deleteworld(
    p_COMMAND_SCHEDULE_ID integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM TBL_BUILDER_COMMAND_WORLD WHERE	COMMAND_SCHEDULE_ID = p_COMMAND_SCHEDULE_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_InsertSchedule

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_insertschedule(
    p_COMMAND_SUBJECT varchar(200),
    p_COMMAND_TEXT varchar(2000),
    p_SCHEDULE_TYPE varchar(2),
    p_SCHEDULE_DATE timestamp,
    p_SCHEDULE_FROM timestamp,
    p_SCHEDULE_TO timestamp,
    p_REPEAT_TYPE varchar(10),
    p_REPEAT_PERIOD varchar(27),
    p_COMMUNICATION_CD varchar(5),
    p_STATUS char(1),
    p_LOGIN_ID varchar(30)
) RETURNS bigint
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_BUILDER_COMMAND_SCHEDULE ( COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE, SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD, COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE ) VALUES ( p_COMMAND_SUBJECT, p_COMMAND_TEXT, p_SCHEDULE_TYPE, p_SCHEDULE_DATE, p_SCHEDULE_FROM, p_SCHEDULE_TO, p_REPEAT_TYPE, p_REPEAT_PERIOD, p_COMMUNICATION_CD, p_STATUS, p_LOGIN_ID, CURRENT_TIMESTAMP );
    RETURN LASTVAL();
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_InsertWorld

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_insertworld(
    p_COMMAND_SCHEDULE_ID integer,
    p_WORLD_ID integer,
    p_COMMUNICATION_CD varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_BUILDER_COMMAND_WORLD ( COMMAND_SCHEDULE_ID, WORLD_ID, COMMUNICATION_CD ) VALUES ( p_COMMAND_SCHEDULE_ID, p_WORLD_ID, p_COMMUNICATION_CD );
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_UpdateSchedule

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_updateschedule(
    p_ID integer,
    p_COMMAND_SUBJECT varchar(200),
    p_COMMAND_TEXT varchar(2000),
    p_SCHEDULE_TYPE varchar(2),
    p_SCHEDULE_DATE timestamp,
    p_SCHEDULE_FROM timestamp,
    p_SCHEDULE_TO timestamp,
    p_REPEAT_TYPE varchar(10),
    p_REPEAT_PERIOD varchar(27),
    p_COMMUNICATION_CD varchar(5),
    p_STATUS char(1),
    p_LOGIN_ID varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_BUILDER_COMMAND_SCHEDULE SET		COMMAND_SUBJECT		= p_COMMAND_SUBJECT, COMMAND_TEXT		= p_COMMAND_TEXT, SCHEDULE_DATE		= p_SCHEDULE_DATE, SCHEDULE_FROM		= p_SCHEDULE_FROM, SCHEDULE_TO			= p_SCHEDULE_TO, REPEAT_TYPE			= p_REPEAT_TYPE, REPEAT_PERIOD		= p_REPEAT_PERIOD, COMMUNICATION_CD	= p_COMMUNICATION_CD, STATUS = p_STATUS::integer, LOGIN_ID			= p_LOGIN_ID, REGDATE				= CURRENT_TIMESTAMP WHERE	ID = p_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_UpdateScheduleCommunicationCD

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_updateschedulecommunicationcd(
    p_ID integer,
    p_COMMUNICATION_CD varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_BUILDER_COMMAND_SCHEDULE SET		COMMUNICATION_CD	= p_COMMUNICATION_CD WHERE	ID = p_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblBuilderCommandScheduleDAO_UpdateWorldCommunicationCD

CREATE OR REPLACE FUNCTION tblbuildercommandscheduledao_updateworldcommunicationcd(
    p_COMMAND_SCHEDULE_ID integer,
    p_WORLD_ID integer,
    p_COMMUNICATION_CD varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	TBL_BUILDER_COMMAND_WORLD SET		COMMUNICATION_CD	= p_COMMUNICATION_CD, EXECUTE_DATE		= CURRENT_TIMESTAMP WHERE	COMMAND_SCHEDULE_ID = p_COMMAND_SCHEDULE_ID AND		WORLD_ID = p_WORLD_ID::integer;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblCharinfoSetDA_CharSetSrch
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblcharinfosetda_charsetsrch(
    p_is_deleted char(1)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select charinfo_setting_id, xml_title, xml_filename, is_deleted, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_CHARINFO_SET ' || ' where is_deleted = ''' || p_is_deleted || ''' ';
    v_sql := v_sql || ' order by charinfo_setting_id desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblCharinfoSetDA_SrchByID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblcharinfosetda_srchbyid(
    p_charinfo_setting_id varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select charinfo_setting_id, xml_title, xml_filename, xml_contents, is_deleted, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_CHARINFO_SET ' || ' where charinfo_setting_id = ''' || p_charinfo_setting_id || ''' ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblCharinfoSetHistoryDA_SrchCharset
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblcharinfosethistoryda_srchcharset(
    p_char_nm varchar(50),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_world_id varchar(3)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1500);
BEGIN
    v_sql := ' select charinfo_setting_id, world_id, char_id, char_nm, status, is_deleted, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_CHARINFO_SET_HISTORY  ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_char_nm != 'null' THEN
    v_sql := v_sql || ' and char_nm=''' || p_char_nm || '''  ';
    END IF;
    IF p_world_id != 'null' THEN
    v_sql := v_sql || ' and world_id=''' || p_world_id || '''  ';
    END IF;
    v_sql := v_sql || ' order by regdate desc, world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblCharinfoSetHistoryDA_SrchList
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblcharinfosethistoryda_srchlist(
    p_is_deleted char(1),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select top ' || p_top_count || ' charinfo_setting_id, world_id, char_id, char_nm, status, is_deleted, login_id, login_nm, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_CHARINFO_SET_HISTORY ' || ' where is_deleted = ''' || p_is_deleted || ''' order by history_id desc';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblChatSearchHistoryDA_SrchChatHistory
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblchatsearchhistoryda_srchchathistory(
    p_login_id varchar(30),
    p_char_nm varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select CHAT_SEARCH_HISTORY_ID,SRCH_CD,SRCH_INFO,ACCOUNT_NM from TBL_CHAT_SEARCH_HISTORY ' || ' where login_id = ''' || p_login_id || ''' and char_nm=''' || p_char_nm || ''' order by chat_search_history_id desc   LIMIT 1';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblChatSearchHistoryDA_SrchChatHistoryByID
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblchatsearchhistoryda_srchchathistorybyid(
    p_chat_search_history_id varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(500);
BEGIN
    v_sql := ' select * from TBL_CHAT_SEARCH_HISTORY ' || ' where chat_search_history_id = ''' || p_chat_search_history_id || ''' ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblChatSearchHistoryDA_SrchChatHistoryList
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblchatsearchhistoryda_srchchathistorylist(
    p_chat_target_type varchar(4),
    p_world_id varchar(5),
    p_chat_target_user varchar(100),
    p_chat_reason_list varchar(4),
    p_log_contents varchar(50),
    p_chat_is_sent varchar(4),
    p_from_date varchar(20),
    p_to_date varchar(20),
    p_all_servers varchar(4),
    p_view_count varchar(5),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1300);
BEGIN
    v_sql := ' select top ' || p_view_count || ' SRCH_CD, SRCH_INFO,CHAT_SEARCH_HISTORY_ID,WORLD_ID,CHAR_ID,CHAR_NM,ACCOUNT_ID,ACCOUNT_NM,LOGIN_ID,LOGIN_NM,CHAR_EMAIL,IS_SENT,TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate,TO_CHAR(from_date, ''YYYY-MM-DD HH24:MI:SS'') from_date,TO_CHAR(to_date, ''YYYY-MM-DD HH24:MI:SS'') to_date ' || ' from TBL_CHAT_SEARCH_HISTORY ' || ' where chat_search_history_id not in (select top ' || p_top_count || ' chat_search_history_id from TBL_CHAT_SEARCH_HISTORY order by chat_search_history_id desc) and regdate between ''' || p_from_date || ''' and ''' || p_to_date || '''  ';
    IF p_all_servers = 'null' THEN
    v_sql := v_sql || ' and ( world_id=''' || p_world_id || ''') ';
    END IF;
    IF p_chat_reason_list != 'NA' THEN
    v_sql := v_sql || ' and ( srch_cd=''' || p_chat_reason_list || ''') ';
    END IF;
    IF p_chat_is_sent != 'NA' THEN
    v_sql := v_sql || ' and ( is_sent=''' || p_chat_is_sent || ''') ';
    END IF;
    IF p_chat_target_type = '1' and p_chat_target_user != 'null' THEN
    v_sql := v_sql || ' and ( account_nm=''' || p_chat_target_user || ''') ';
    END IF;
    IF p_chat_target_type = '2' and p_chat_target_user != 'null' THEN
    v_sql := v_sql || ' and ( char_nm=''' || p_chat_target_user || ''') ';
    END IF;
    IF p_chat_target_type = '3' and p_chat_target_user != 'null' THEN
    v_sql := v_sql || ' and ( char_email=''' || p_chat_target_user || ''') ';
    END IF;
    IF p_chat_target_type = '4' and p_chat_target_user != 'null' THEN
    v_sql := v_sql || ' and ( login_id=''' || p_chat_target_user || ''') ';
    END IF;
    IF p_log_contents != 'null' THEN
    v_sql := v_sql || ' and ( log_contents like ''%' || p_log_contents || '%'') ';
    END IF;
    v_sql := v_sql || ' order by chat_search_history_id desc, world_id asc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblForbiddenDA_SrchForbiddenList

CREATE OR REPLACE FUNCTION tblforbiddenda_srchforbiddenlist(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.FORBIDDEN_TYPE, t1.servers, t1.forbidden_id, t1.login_id, t1.pub_status, TO_CHAR(t1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate , t2.login_nm from tbl_forbidden t1, tbl_admin_user t2 where t1.login_id = t2.login_id order by t1.forbidden_id desc;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticeContentsDA_SrchNoticeSentence

CREATE OR REPLACE FUNCTION tblgamenoticecontentsda_srchnoticesentence(
    p_notice_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.notice_contents_id, T1.notice_id, T1.notice_sentence, T2.notice_category, t2.notice_pos_type, t2.notice_count, t2.NOTICE_RACE, t2.NOTICE_CLASS from tbl_game_notice_contents T1, TBL_GAME_NOTICE_SCHEDULE T2 where T1.notice_id = p_notice_id AND T1.NOTICE_ID = T2.NOTICE_ID;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameNoticeHistoryDA_SrchHistory
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgamenoticehistoryda_srchhistory(
    p_notice_id varchar(30),
    p_world_id varchar(10),
    p_from_date varchar(50),
    p_to_date varchar(50)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select * ' || ' from TBL_GAME_NOTICE_HISTORY ' || ' where notice_id = ''' || p_notice_id || ''' AND regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_world_id IS NOT NULL THEN
    v_sql := v_sql || ' and world_id = ''' || p_world_id || '''';
    END IF;
    v_sql := v_sql || ' order by notice_history_id desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticeHistoryDAO_InsertNoticeHistory

CREATE OR REPLACE FUNCTION tblgamenoticehistorydao_insertnoticehistory(
    p_notice_id varchar(30),
    p_world_id integer,
    p_communication_cd varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TBL_GAME_NOTICE_HISTORY VALUES(p_notice_id, p_world_id, p_communication_cd, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDA_Srch

CREATE OR REPLACE FUNCTION tblgamenoticepresetda_srch(
    p_subject varchar(200),
    p_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF (p_subject = '') THEN
    PERFORM  ID, NOTICE_SUBJECT, NOTICE_CATEGORY, NOTICE_TYPE, NOTICE_POS_TYPE, LOGIN_ID, REGDATE, NOTICE_RACE, NOTICE_CLASS from	TBL_GAME_NOTICE_PRESET where	status = 'Y' order by id desc LIMIT p_count;
    ELSE
    PERFORM  ID, NOTICE_SUBJECT, NOTICE_CATEGORY, NOTICE_TYPE, NOTICE_POS_TYPE, LOGIN_ID, REGDATE, NOTICE_RACE, NOTICE_CLASS from	TBL_GAME_NOTICE_PRESET where	NOTICE_SUBJECT like '%' || p_subject || '%' and		status = 'Y' order by id desc LIMIT p_count;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDA_SrchById

CREATE OR REPLACE FUNCTION tblgamenoticepresetda_srchbyid(
    p_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	ID, NOTICE_SUBJECT, NOTICE_CATEGORY, NOTICE_TYPE, NOTICE_POS_TYPE, LOGIN_ID, REGDATE, NOTICE_RACE, NOTICE_CLASS from	TBL_GAME_NOTICE_PRESET where	id = p_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDA_SrchContentsByPresetId

CREATE OR REPLACE FUNCTION tblgamenoticepresetda_srchcontentsbypresetid(
    p_PRESET_ID integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	ID, PRESET_ID, SENTENCE from	TBL_GAME_NOTICE_PRESET_CONTENTS where	PRESET_ID = p_PRESET_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDAO_DeleteContents

CREATE OR REPLACE FUNCTION tblgamenoticepresetdao_deletecontents(
    p_PRESET_ID integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM TBL_GAME_NOTICE_PRESET_CONTENTS where	PRESET_ID = p_PRESET_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDAO_Insert

CREATE OR REPLACE FUNCTION tblgamenoticepresetdao_insert(
    p_NOTICE_SUBJECT varchar(200),
    p_NOTICE_CATEGORY char(1),
    p_NOTICE_TYPE char(2),
    p_NOTICE_POS_TYPE char(1),
    p_LOGIN_ID varchar(30),
    p_NOTICE_RACE varchar(100),
    p_NOTICE_CLASS varchar(300)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    insert into TBL_GAME_NOTICE_PRESET (NOTICE_SUBJECT, NOTICE_CATEGORY, NOTICE_TYPE, NOTICE_POS_TYPE, LOGIN_ID, REGDATE, NOTICE_RACE, NOTICE_CLASS, STATUS) values (p_NOTICE_SUBJECT, p_NOTICE_CATEGORY, p_NOTICE_TYPE, p_NOTICE_POS_TYPE, p_LOGIN_ID, CURRENT_TIMESTAMP, p_NOTICE_RACE, p_NOTICE_CLASS, 'Y');
    RETURN QUERY SELECT LASTVAL();
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDAO_InsertContents

CREATE OR REPLACE FUNCTION tblgamenoticepresetdao_insertcontents(
    p_PRESET_ID integer,
    p_SENTENCE varchar(200)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    insert into TBL_GAME_NOTICE_PRESET_CONTENTS (PRESET_ID, SENTENCE) values (p_PRESET_ID, p_SENTENCE);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDAO_Update

CREATE OR REPLACE FUNCTION tblgamenoticepresetdao_update(
    p_ID integer,
    p_NOTICE_SUBJECT varchar(200),
    p_NOTICE_CATEGORY char(1),
    p_NOTICE_TYPE char(2),
    p_NOTICE_POS_TYPE char(1),
    p_LOGIN_ID varchar(30),
    p_NOTICE_RACE varchar(100),
    p_NOTICE_CLASS varchar(300)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    update	TBL_GAME_NOTICE_PRESET set		NOTICE_SUBJECT = p_NOTICE_SUBJECT, NOTICE_CATEGORY = p_NOTICE_CATEGORY, NOTICE_TYPE = p_NOTICE_TYPE, NOTICE_POS_TYPE = p_NOTICE_POS_TYPE, LOGIN_ID = p_LOGIN_ID, REGDATE = CURRENT_TIMESTAMP, NOTICE_RACE = p_NOTICE_RACE, NOTICE_CLASS = p_NOTICE_CLASS where	ID = p_ID;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticePresetDAO_UpdateStatus

CREATE OR REPLACE FUNCTION tblgamenoticepresetdao_updatestatus(
    p_id integer,
    p_status char(1)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    update	TBL_GAME_NOTICE_PRESET set		STATUS = p_status::integer where	id = p_id;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticeScheduleDA_SrchByNoticeID

CREATE OR REPLACE FUNCTION tblgamenoticescheduleda_srchbynoticeid(
    p_notice_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT NOTICE_RACE, NOTICE_CLASS, notice_pos_type, notice_id, notice_repeat, notice_repeat_min, notice_category, notice_subject, notice_type, substring(TO_CHAR(notice_from, 'YYYY-MM-DD HH24:MI:SS'), 0, 17) notice_from, substring(TO_CHAR(notice_to, 'YYYY-MM-DD HH24:MI:SS'), 0, 17) notice_to, notice_period, notice_week, notice_month, period_hour, period_min, communication_cd, notice_count, notice_status, login_id, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate from TBL_GAME_NOTICE_SCHEDULE where notice_id = p_notice_id;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] TblGameNoticeScheduleDA_SrchNotices
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION tblgamenoticescheduleda_srchnotices(
    p_notice_subject varchar(200),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_from_date varchar(50),
    p_to_date varchar(50),
    p_notice_type char(2),
    p_notice_status char(1),
    p_notice_category varchar(30),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(1000);
BEGIN
    v_sql := ' select top ' || p_top_count || ' notice_pos_type, notice_id, notice_repeat, notice_repeat_min, notice_category, notice_subject, notice_type, TO_CHAR(notice_from, ''YYYY-MM-DD HH24:MI:SS'') notice_from , TO_CHAR(notice_to, ''YYYY-MM-DD HH24:MI:SS'') notice_to, notice_period, notice_week, notice_month, period_hour, period_min, communication_cd, notice_count, notice_status, login_id, TO_CHAR(regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate ' || ' from TBL_GAME_NOTICE_SCHEDULE ' || ' where regdate between ''' || p_from_date || ''' and ''' || p_to_date || ''' ';
    IF p_period_hour IS NOT NULL THEN
    v_sql := v_sql || ' and period_hour = ''' || p_period_hour || '''';
    END IF;
    IF p_period_min IS NOT NULL THEN
    v_sql := v_sql || ' and period_min = ''' || p_period_min || '''';
    END IF;
    IF p_notice_subject != 'null' THEN
    v_sql := v_sql || ' and notice_subject like ''%' || p_notice_subject || '%''';
    END IF;
    IF p_notice_status IS NOT NULL THEN
    v_sql := v_sql || ' and notice_status = ''' || p_notice_status || '''';
    END IF;
    IF p_notice_type IS NOT NULL THEN
    v_sql := v_sql || ' and notice_type = ''' || p_notice_type || '''';
    END IF;
    IF p_notice_category IS NOT NULL THEN
    v_sql := v_sql || ' and notice_category = ''' || p_notice_category || '''';
    END IF;
    v_sql := v_sql || ' order by regdate desc ';
    EXECUTE v_sql;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] TblGameNoticeScheduleDA_SrchReservedSchedule

CREATE OR REPLACE FUNCTION tblgamenoticescheduleda_srchreservedschedule(
    p_current_time varchar(30),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_notice_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT NOTICE_RACE, NOTICE_CLASS, notice_pos_type, notice_id, notice_repeat, notice_repeat_min, notice_category, notice_subject, notice_type, notice_from, notice_to, notice_period, notice_week, notice_month, period_hour, period_min, communication_cd, notice_count, notice_status, login_id, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate from TBL_GAME_NOTICE_SCHEDULE where ((NOTICE_TO >= p_current_time and NOTICE_FROM <= p_current_time and PERIOD_HOUR = p_period_hour AND PERIOD_MIN = p_period_min) or (NOTICE_TO >= p_current_time and NOTICE_FROM <= p_current_time and notice_repeat_min != 0) or (notice_period = 'ONCE' and communication_cd = 'BEF')) AND NOTICE_STATUS = p_notice_status and communication_cd != 'TRA' order by regdate ASC;
END;
$$;

-- --------------------------------------------------------

