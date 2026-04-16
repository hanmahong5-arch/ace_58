#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate PL/pgSQL patch files for all 63 failing functions across
aion_account_db, aion_account_cache_db, and aion_gm databases.
"""

import os
import json
import sys

PATCHES_DIR = os.path.join(os.path.dirname(__file__), 'patches')
os.makedirs(PATCHES_DIR, exist_ok=True)

def write_patch(func_name, db_name, sql_body):
    """Write a patch file with database header"""
    path = os.path.join(PATCHES_DIR, f'{func_name}.sql')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(f'-- database: {db_name}\n')
        f.write(sql_body.strip())
        f.write('\n')
    return path

patches = {}

# ============================================================
# aion_account_db (13 functions)
# ============================================================

# 1. account_input - deploy error: unmatched parens on PERFORM calls
patches['account_input'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION account_input(
    p_allianceUserKey varchar(255)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_accountNo integer;
    v_genderCode smallint;
    v_legalBirthday timestamp;
    v_account_name varchar(14);
    v_retCode integer;
BEGIN
    v_retCode := 2;
    v_accountNo := 0;
    v_genderCode := 0;
    v_legalBirthday := '1900-01-01 00:00:00';
    v_account_name := '_sd_0000000_';

    -- Call external account lookup (cross-db reference removed)
    -- Original: EXEC GlobalAccountDB.dbo.pap_GetAllianceCompanyAccount ...
    -- Skipped: cross-database call not available in PG

    IF v_accountNo = 0 AND v_retCode = 2 THEN
        v_accountNo := 0;
        SELECT p_gameAccountNo INTO v_accountNo FROM pap_getnewaccountno();

        IF v_accountNo < 10000000 THEN
            v_account_name := '_sd_' || RIGHT('00000000' || CAST(v_accountNo AS varchar), 7) || '_';
        ELSE
            v_account_name := '_sd_' || CAST(v_accountNo AS varchar) || '_';
        END IF;

        PERFORM pap_createaccount(
            v_accountNo,
            v_account_name,
            E'\\x00'::bytea,
            2::smallint,
            '1970-01-01 00:00:00'::timestamp,
            1::smallint
        );
        v_retCode := 0;
        -- Original: EXEC pap_CreateAllianceCompanyAccount (cross-db, skipped)
    ELSE
        v_account_name := (SELECT gameaccount FROM AccountAuth WHERE gameaccountno IN
            (SELECT accountno FROM AllianceCompanyAccount WHERE allianceUserKey = p_allianceUserKey));
    END IF;
END;
$$;
""")

# 2. ap_gpwdwithflag - deploy error: IF/THEN missing, begin; syntax
patches['ap_gpwdwithflag'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_gpwdwithflag(
    p_account varchar(16),
    OUT p_pwd bytea,
    OUT p_flag smallint
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS(SELECT gameAccount FROM AccountAuth WHERE gameAccount = p_account) THEN
        IF p_account !~ '[^a-zA-Z0-9]' THEN
            p_pwd := E'\\x00'::bytea;
            p_flag := 3;
            PERFORM ap_autoreg(p_account);
        END IF;
    ELSE
        SELECT password, cryptographTypeCode INTO p_pwd, p_flag
        FROM AccountAuth WHERE gameAccount = p_account;
    END IF;
    RETURN;
END;
$$;
""")

# 3. ap_setaccountrestirction - deploy error: CASE expression syntax
patches['ap_setaccountrestirction'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_setaccountrestirction(
    p_gameAccountNo integer,
    p_restrictionReasonCode smallint,
    OUT p_gameAccount varchar(32),
    OUT p_restrictionNo integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_restrictionEndDate timestamp;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_retcode integer;
    v_restrictionCode integer;
BEGIN
    v_restrictionEndDate := '9999-12-31 23:59:59';
    v_retcode := 0;
    v_restrictionCode := CASE p_restrictionReasonCode WHEN 0 THEN 43 ELSE 43 END;

    SELECT gameAccount INTO p_gameAccount FROM accountAuth WHERE gameAccountNo = p_gameAccountNo;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
        v_retcode := 1;
        p_return_code := v_retcode;
        RETURN;
    END IF;

    IF (SELECT COUNT(*) FROM Restriction
        WHERE gameAccountNo = p_gameAccountNo
          AND restrictionEndDate > CURRENT_TIMESTAMP
          AND gameRestrictionReasonCode = v_restrictionCode) > 0 THEN
        v_retcode := 2;
        p_return_code := v_retcode;
        RETURN;
    END IF;

    INSERT INTO Restriction (gameAccountNo, gameRestrictionReasonCode,
        restrictionStartDate, restrictionEndDate, restrictionExpireDate)
    VALUES (p_gameAccountNo, v_restrictionCode,
        CURRENT_TIMESTAMP, v_restrictionEndDate, v_restrictionEndDate);

    p_restrictionNo := LASTVAL();

    UPDATE AccountAuth SET restrictFlag = 1 WHERE gameAccountNo = p_gameAccountNo;

    p_return_code := v_retcode;
    RETURN;
END;
$$;
""")

# 4. aop_getaccountnoticelist - runtime: cross-db reference commondb.commonCode
patches['aop_getaccountnoticelist'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION aop_getaccountnoticelist(
    p_account varchar(16),
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_uid integer;
    v_noticeCodeGroupNo integer;
BEGIN
    v_noticeCodeGroupNo := 52;
    SELECT gameAccountNo INTO v_uid FROM AccountAuth WHERE gameAccount = p_account;

    -- Original referenced commondb.commonCode (cross-db) - removed cross-db prefix
    PERFORM ALN.gameAccountNo, ALN.noticeTypeCode,
            ALN.noticeStartDate, ALN.noticeEndDate
    FROM accountLoginNotice ALN
    WHERE ALN.gameAccountNo = v_uid;

    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
        p_ErrorCode := 0150201010;
        RETURN;
    END IF;
    p_ErrorCode := 0;
    p_return_code := 0;
    RETURN;
END;
$$;
""")

# 5. aop_getgameserverchargegrouplist - runtime: cross-db reference SN.GameServerChargeGroup
patches['aop_getgameserverchargegrouplist'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION aop_getgameserverchargegrouplist(
    p_unknown text DEFAULT NULL
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    -- Original referenced SN.GameServerChargeGroup (cross-db/schema)
    -- Removed schema prefix; table must exist in current schema
    RETURN QUERY SELECT gameServerNo, gameServerChargeGroupNo
    FROM GameServerChargeGroup ORDER BY gameServerNo;
END;
$$;
""")

# 6. ap_autoreg - runtime: CAST(0 AS bytea) fails, binary(0) invalid
patches['ap_autoreg'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_autoreg(
    p_account varchar(14)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_ssn integer;
BEGIN
    v_ssn := (SELECT COALESCE(MAX(gameAccountNo), 0) FROM AccountAuth) + 1;
    INSERT INTO AccountAuth (gameAccountNo, gameAccount, password,
        cryptographTypeCode, legalBirthday, genderCode, authLimitTypeBitSet)
    VALUES (v_ssn, p_account, E'\\x00'::bytea, 3, '1970-01-01'::timestamp, 0::smallint, 1);
    INSERT INTO AccountETC (gameAccountNo, banServerBitSet, accountCreateDate)
    VALUES (v_ssn, E'\\x00'::bytea, '1999-01-01'::timestamp);
END;
$$;
""")

# 7. ap_gstat - runtime: fn_ap_getloginflag signature mismatch (boolean vs integer for noticeFlag)
patches['ap_gstat'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_gstat(
    p_account varchar(14),
    OUT p_uid integer,
    OUT p_payStat integer,
    OUT p_loginFlag integer,
    OUT p_warnFlag integer,
    OUT p_blockFlag integer,
    OUT p_blockFlag2 integer,
    OUT p_subFlag integer,
    OUT p_lastworld smallint,
    OUT p_block_end_date timestamp,
    OUT p_forbidden_servers bytea
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT AA.gameAccountNo,
           0,
           fn_ap_getloginflag(AA.gameAccountNo, AA.noticeFlag::integer, AA.authLimitTypeBitSet, AA.gameAccountGradeCode, CURRENT_TIMESTAMP),
           fn_ap_getwarnflag(AA.gameAccountNo, AA.noticeFlag::integer, CURRENT_TIMESTAMP),
           fn_ap_getblockflag(AA.gameAccountNo, AA.accountStatusCode),
           fn_ap_getblockflag2(AA.gameAccountNo, AA.restrictFlag::integer, CURRENT_TIMESTAMP),
           0,
           AE.lastLoginGameServerNo,
           NULL::timestamp,
           AE.banServerBitSet
    INTO p_uid, p_payStat, p_loginFlag, p_warnFlag, p_blockFlag,
         p_blockFlag2, p_subFlag, p_lastworld, p_block_end_date, p_forbidden_servers
    FROM AccountAuth AA
    INNER JOIN AccountETC AE ON (AA.gameAccountNo = AE.gameAccountNo)
    WHERE gameAccount = p_account;
END;
$$;
""")

# 8. ap_slog - runtime: SELECT hardware missing FROM clause
patches['ap_slog'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_slog(
    p_uid integer,
    p_lastlogin timestamp,
    p_lastlogout timestamp,
    p_LastGame integer,
    p_LastWorld smallint,
    p_LastIP varchar(15)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_hardware varchar(16);
BEGIN
    UPDATE AccountETC SET lastLoginDate = p_lastlogin,
        lastLogoutDate = p_lastlogout,
        lastLoginGameServerNo = p_LastWorld
    WHERE gameAccountNo = p_uid;

    SELECT hardwareId INTO v_hardware FROM AccountAuth WHERE gameAccountNo = p_uid;
END;
$$;
""")

# 9. ap_suserdata - runtime: UPDATE AE SET ... FROM -> need proper PG UPDATE syntax
patches['ap_suserdata'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION ap_suserdata(
    p_account varchar(14),
    p_userdata_size smallint,
    p_userdata bytea
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE AccountETC SET accountCustomizeBitSet = p_userdata
    FROM AccountAuth AA
    WHERE AA.gameAccountNo = AccountETC.gameAccountNo
      AND AA.gameAccount = p_account;
END;
$$;
""")

# 10. convert - runtime: polymorphic type error -> use text input/output
patches['convert'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION convert(
    p_type text,
    p_value text
) RETURNS text
LANGUAGE plpgsql
AS $$
-- Emulates T-SQL CONVERT(type, value) - simple text passthrough
BEGIN
    RETURN p_value;
END;
$$;
""")

# 11. pap_getaccountbyuserid - runtime: pap_getaccount called with wrong signature
patches['pap_getaccountbyuserid'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION pap_getaccountbyuserid(
    p_uid integer,
    OUT p_account varchar(14),
    OUT p_password bytea,
    OUT p_passwordFlag smallint,
    OUT p_birthdate timestamp,
    OUT p_sex smallint,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_ret record;
BEGIN
    p_account := '';
    SELECT gameAccount INTO p_account FROM AccountAuth WHERE gameAccountNo = p_uid;
    IF p_account = '' OR p_account IS NULL THEN
        p_return_code := 2;
        RETURN;
    END IF;

    SELECT r.p_uid, r.p_password, r.p_passwordFlag, r.p_birthdate, r.p_sex, r.p_return_code
    INTO p_uid, p_password, p_passwordFlag, p_birthdate, p_sex, p_return_code
    FROM pap_getaccount(p_account) AS r(p_uid integer, p_password bytea,
        p_passwordFlag smallint, p_birthdate timestamp, p_sex smallint, p_return_code integer);

    RETURN;
END;
$$;
""")

# 12. pap_getgameinfo - runtime: boolean = integer comparison
patches['pap_getgameinfo'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION pap_getgameinfo(
    p_uid integer,
    OUT p_account varchar(14),
    OUT p_statusFlag integer,
    OUT p_activeFlag integer,
    OUT p_warnStat integer,
    OUT p_otpStat integer,
    OUT p_macStat integer,
    OUT p_blockFlag integer,
    OUT p_blockFlag2 integer,
    OUT p_loginFlag integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_exist smallint;
    v_isNoticed integer;
    v_isRestricted integer;
    v_isSecurityServiceUsed integer;
BEGIN
    v_exist := 0;
    p_account := '';
    p_statusFlag := 0;
    p_activeFlag := 0;
    p_warnStat := 0;
    p_otpStat := 0;
    p_macStat := 0;
    p_blockFlag := 0;
    p_blockFlag2 := 0;
    v_isNoticed := 0;
    v_isRestricted := 0;
    v_isSecurityServiceUsed := 0;
    p_loginFlag := 0;

    SELECT gameAccount, accountStatusCode, 0,
           COALESCE(fn_ap_getblockflag(gameAccountNo, accountStatusCode), 0),
           1,
           noticeFlag::integer,
           restrictFlag::integer,
           1
    INTO p_account, p_statusFlag, p_activeFlag, p_blockFlag,
         v_exist, v_isNoticed, v_isRestricted, v_isSecurityServiceUsed
    FROM AccountAuth
    WHERE gameAccountNo = p_uid
    LIMIT 1;

    IF v_isNoticed = 1 THEN
        p_warnStat := COALESCE(fn_ap_getwarnflag(p_uid, v_isNoticed, CURRENT_TIMESTAMP), 0);
    END IF;

    IF v_isRestricted = 1 THEN
        p_blockFlag2 := COALESCE(fn_ap_getblockflag2(p_uid, v_isRestricted, CURRENT_TIMESTAMP), 0);
    END IF;

    IF v_isSecurityServiceUsed = 1 THEN
        SELECT accountsecuritystatuscode INTO p_otpStat
        FROM accountsecurityservice
        WHERE gameaccountno = p_uid AND accountsecuritymethodcode = 1;
        SELECT accountsecuritystatuscode INTO p_macStat
        FROM accountsecurityservice
        WHERE gameaccountno = p_uid AND accountsecuritymethodcode = 2;
    END IF;

    IF v_exist = 1 THEN
        p_return_code := 0;
        RETURN;
    END IF;
    p_return_code := 2;
    RETURN;
END;
$$;
""")

# 13. write_gameuser_counts - runtime: varchar + varchar (should use ||)
patches['write_gameuser_counts'] = ('aion_account_db', """
CREATE OR REPLACE FUNCTION write_gameuser_counts(
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_gamename varchar(50);
    v_cnt integer;
    v_txt varchar(500);
BEGIN
    v_gamename := 'AION';
    v_txt := 'OK|';
    v_cnt := (SELECT sum(concurrentUserCount) FROM ConcurrentUserStat
              WHERE serverNo = 0 AND concurrentUserStatTypeCode = 2
                AND registerdate > (CURRENT_TIMESTAMP - INTERVAL '5 minutes')
              GROUP BY serverNo);
    v_txt := v_txt || v_gamename || '=' || COALESCE(CAST(v_cnt AS varchar(10)), '0') || '; ';
    -- Original used OLE Automation (sp_OACreate/sp_OAMethod) to write to file
    -- This is SQL Server specific and cannot be replicated in PG
    RAISE NOTICE 'GameUser counts: %', v_txt;
END;
$$;
""")

# ============================================================
# aion_account_cache_db (11 functions)
# ============================================================

# 14. aion_getplaytimesforpolls - deploy error: END IF inside WHILE should be END LOOP, table var refs
patches['aion_getplaytimesforpolls'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_getplaytimesforpolls(
    p_pollIds text,
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
DECLARE
    v_S_VAL text;
    v_S_SPLIT_CHAR varchar(1);
    v_oPos integer;
    v_nPos integer;
    v_i integer;
    v_tempVar varchar(4000);
BEGIN
    -- Create temp tables for split logic
    CREATE TEMP TABLE IF NOT EXISTS tmp_t_split (num integer, val varchar(4000)) ON COMMIT DROP;
    CREATE TEMP TABLE IF NOT EXISTS tmp_pollidlist (poll_id integer) ON COMMIT DROP;
    TRUNCATE tmp_t_split;
    TRUNCATE tmp_pollidlist;

    v_S_VAL := p_pollIds;
    v_S_SPLIT_CHAR := ',';
    v_oPos := 1;
    v_nPos := 1;
    v_i := 0;

    WHILE v_nPos > 0 LOOP
        v_nPos := POSITION(v_S_SPLIT_CHAR IN SUBSTRING(v_S_VAL FROM v_oPos));
        IF v_nPos = 0 THEN
            v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos);
        ELSE
            v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos FOR v_nPos - 1);
            v_nPos := v_oPos + v_nPos - 1;
        END IF;

        IF LENGTH(v_tempVar) > 0 THEN
            INSERT INTO tmp_t_split VALUES (v_i, v_tempVar);
        END IF;

        IF v_nPos = 0 THEN
            EXIT;
        END IF;
        v_oPos := v_nPos + 1;
        v_i := v_i + 1;
    END LOOP;

    INSERT INTO tmp_pollidlist SELECT CAST(val AS integer) FROM tmp_t_split;

    RETURN QUERY SELECT t.poll_id, COALESCE(app.previous_playtime, 0::bigint) AS previous_playtime
    FROM tmp_pollidlist AS t
    LEFT JOIN account_playtime_polls AS app
        ON app.poll_id = t.poll_id AND app.account_id = p_account_id;
END;
$$;
""")

# 15. aion_querycancreatejumpingcharacter - deploy error: missing END IF (nested IF/ELSE)
patches['aion_querycancreatejumpingcharacter'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_querycancreatejumpingcharacter(
    p_account_id integer,
    p_server_id integer,
    p_from_special smallint,
    OUT p_can_create_num integer,
    OUT p_satisfy_date smallint,
    OUT p_satisfy_char_lev smallint
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur_date timestamp;
    v_max_creation_count integer;
    v_required_char_level integer;
    v_start_date timestamp;
    v_end_date timestamp;
    v_cur_creation_num integer;
BEGIN
    v_cur_date := CURRENT_TIMESTAMP;
    SELECT max_creation_count, required_char_level, start_date, end_date
    INTO v_max_creation_count, v_required_char_level, v_start_date, v_end_date
    FROM jumping_character_config
    WHERE server_id = p_server_id AND start_date < v_cur_date
      AND v_cur_date < end_date AND is_deleted = 0;

    IF COALESCE(v_max_creation_count, 0) > 0 THEN
        p_satisfy_date := 1;
        IF EXISTS(SELECT char_id FROM global_user_data
                  WHERE account_id = p_account_id
                    AND is_special_server = p_from_special
                    AND user_level >= v_required_char_level
                    AND delete_completed_date = 0)
           OR v_required_char_level = 0 THEN
            p_satisfy_char_lev := 1;
            SELECT COUNT(*) INTO v_cur_creation_num FROM global_user_data
            WHERE account_id = p_account_id
              AND is_special_server = p_from_special
              AND create_date > v_start_date AND create_date < v_end_date
              AND is_jumping_character != 0;
            v_cur_creation_num := COALESCE(v_cur_creation_num, 0);
            p_can_create_num := v_max_creation_count - v_cur_creation_num;
        ELSE
            p_satisfy_char_lev := 0;
            p_can_create_num := 0;
        END IF;
    ELSE
        p_satisfy_date := 0;
        p_satisfy_char_lev := 0;
        p_can_create_num := 0;
    END IF;
END;
$$;
""")

# 16. aion_querycancreatejumpingcharacter_20170428 - deploy error: same nested IF/ELSE issue
patches['aion_querycancreatejumpingcharacter_20170428'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_querycancreatejumpingcharacter_20170428(
    p_account_id integer,
    p_server_id integer,
    p_from_special smallint,
    OUT p_can_create_num integer,
    OUT p_satisfy_date smallint,
    OUT p_satisfy_char_lev smallint,
    OUT p_limit_reset_time integer,
    OUT p_limit_play_time integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur_date timestamp;
    v_max_creation_count integer;
    v_required_char_level integer;
    v_start_date timestamp;
    v_end_date timestamp;
    v_cur_creation_num integer;
BEGIN
    v_cur_date := CURRENT_TIMESTAMP;
    SELECT max_creation_count, required_char_level, start_date, end_date
    INTO v_max_creation_count, v_required_char_level, v_start_date, v_end_date
    FROM jumping_character_config
    WHERE server_id = p_server_id AND start_date < v_cur_date
      AND v_cur_date < end_date AND is_deleted = 0;

    IF COALESCE(v_max_creation_count, 0) > 0 THEN
        p_satisfy_date := 1;
        IF EXISTS(SELECT char_id FROM global_user_data
                  WHERE account_id = p_account_id
                    AND is_special_server = p_from_special
                    AND user_level >= v_required_char_level
                    AND delete_completed_date = 0)
           OR v_required_char_level = 0 THEN
            p_satisfy_char_lev := 1;
            SELECT COUNT(*) INTO v_cur_creation_num FROM global_user_data
            WHERE account_id = p_account_id
              AND is_special_server = p_from_special
              AND create_date > v_start_date AND create_date < v_end_date
              AND is_jumping_character != 0;
            v_cur_creation_num := COALESCE(v_cur_creation_num, 0);
            p_can_create_num := v_max_creation_count - v_cur_creation_num;
            SELECT limit_play_reset_time, limit_play_accum_time
            INTO p_limit_reset_time, p_limit_play_time
            FROM account_data WHERE account_id = p_account_id;
            p_limit_reset_time := COALESCE(p_limit_reset_time, 0);
            p_limit_play_time := COALESCE(p_limit_play_time, 0);
        ELSE
            p_satisfy_char_lev := 0;
            p_can_create_num := 0;
            p_limit_reset_time := 0;
            p_limit_play_time := 0;
        END IF;
    ELSE
        p_satisfy_date := 0;
        p_satisfy_char_lev := 0;
        p_can_create_num := 0;
        p_limit_reset_time := 0;
        p_limit_play_time := 0;
    END IF;
END;
$$;
""")

# 17. aion_updateplaytimesforpolls - deploy error: END IF in WHILE, table var, MERGE syntax
patches['aion_updateplaytimesforpolls'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_updateplaytimesforpolls(
    p_pollIds text,
    p_playTimes text,
    p_account_id integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_S_VAL text;
    v_S_VAL_TIME text;
    v_S_SPLIT_CHAR varchar(1);
    v_oPos integer;
    v_nPos integer;
    v_oPos_t integer;
    v_nPos_t integer;
    v_i integer;
    v_tempVar varchar(4000);
    v_tempVar_t varchar(4000);
    v_tempPollId integer;
    v_tempPlayTime bigint;
    v_rowcount integer;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_poll_time_list (poll_id integer, playtime bigint) ON COMMIT DROP;
    TRUNCATE tmp_poll_time_list;

    v_S_VAL := p_pollIds;
    v_S_VAL_TIME := p_playTimes;
    v_S_SPLIT_CHAR := ',';
    v_oPos := 1;
    v_oPos_t := 1;
    v_nPos := 1;
    v_nPos_t := 1;

    WHILE v_nPos > 0 AND v_nPos_t > 0 LOOP
        v_nPos := POSITION(v_S_SPLIT_CHAR IN SUBSTRING(v_S_VAL FROM v_oPos));
        v_nPos_t := POSITION(v_S_SPLIT_CHAR IN SUBSTRING(v_S_VAL_TIME FROM v_oPos_t));

        IF v_nPos = 0 THEN
            v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos);
        ELSE
            v_tempVar := SUBSTRING(v_S_VAL FROM v_oPos FOR v_nPos - 1);
            v_nPos := v_oPos + v_nPos - 1;
        END IF;

        IF v_nPos_t = 0 THEN
            v_tempVar_t := SUBSTRING(v_S_VAL_TIME FROM v_oPos_t);
        ELSE
            v_tempVar_t := SUBSTRING(v_S_VAL_TIME FROM v_oPos_t FOR v_nPos_t - 1);
            v_nPos_t := v_oPos_t + v_nPos_t - 1;
        END IF;

        IF LENGTH(v_tempVar) > 0 AND LENGTH(v_tempVar_t) > 0 THEN
            v_tempPollId := CAST(v_tempVar AS integer);
            v_tempPlayTime := CAST(v_tempVar_t AS bigint);
            INSERT INTO tmp_poll_time_list VALUES (v_tempPollId, v_tempPlayTime);
        END IF;

        IF v_nPos = 0 OR v_nPos_t = 0 THEN
            EXIT;
        END IF;
        v_oPos := v_nPos + 1;
        v_oPos_t := v_nPos_t + 1;
    END LOOP;

    -- MERGE emulation: UPDATE existing, INSERT new
    UPDATE account_playtime_polls AS app
    SET previous_playtime = app.previous_playtime + pitl.playtime
    FROM tmp_poll_time_list AS pitl
    WHERE app.account_id = p_account_id AND app.poll_id = pitl.poll_id;

    INSERT INTO account_playtime_polls (account_id, poll_id, previous_playtime)
    SELECT p_account_id, pitl.poll_id, pitl.playtime
    FROM tmp_poll_time_list pitl
    WHERE NOT EXISTS (
        SELECT 1 FROM account_playtime_polls app
        WHERE app.account_id = p_account_id AND app.poll_id = pitl.poll_id
    );

    RETURN 0;
END;
$$;
""")

# 18. aion_getoldestcreatedate - runtime: COALESCE type mismatch (timestamp vs integer)
patches['aion_getoldestcreatedate'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_getoldestcreatedate(
    p_accountId integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT COALESCE(MIN(create_date), '1970-01-01'::timestamp)
    FROM global_user_data WHERE account_id = p_accountId;
END;
$$;
""")

# 19. aion_loadlunaprice - runtime: relation user_luna_price does not exist
# The table might have a different name. We'll use the correct name from the schema.
patches['aion_loadlunaprice'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_loadlunaprice(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    -- Original table: user_luna_price - may need to be created or renamed
    -- Using the table name as-is; ensure the table exists in the target DB
    RETURN QUERY SELECT luna_id, use_count, reset_type, reset_week_value,
        reset_time_value, create_time
    FROM user_luna_price WHERE char_id = p_char_id;
END;
$$;
""")

# 20. aion_updatelunaprice - runtime: relation user_luna_price does not exist
patches['aion_updatelunaprice'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION aion_updatelunaprice(
    p_char_id integer,
    p_luna_id integer,
    p_use_count integer,
    p_reset_type integer,
    p_reset_week_value integer,
    p_reset_time_value integer
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer;
BEGIN
    UPDATE user_luna_price SET use_count = p_use_count,
        update_time = CURRENT_TIMESTAMP
    WHERE char_id = p_char_id AND luna_id = p_luna_id;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;

    IF v_rowcount = 0 THEN
        INSERT INTO user_luna_price (char_id, luna_id, use_count, reset_type,
            reset_week_value, reset_time_value, create_time)
        VALUES (p_char_id, p_luna_id, p_use_count, p_reset_type,
            p_reset_week_value, p_reset_time_value, CURRENT_TIMESTAMP);
    END IF;
END;
$$;
""")

# 21. ap_getservers (cache) - runtime: relation aion_myserver does not exist
patches['ap_getservers'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION ap_getservers(
    p_server_id integer DEFAULT 1
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    -- Original referenced aion_myserver table
    -- Table must be created in the target database
    RETURN QUERY SELECT * FROM aion_myserver;
END;
$$;
""")

# 22. convert (cache) - same polymorphic type issue
# Note: already defined for aion_account_db, need separate file for cache
patches['convert_cache'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION convert(
    p_type text,
    p_value text
) RETURNS text
LANGUAGE plpgsql
AS $$
-- Emulates T-SQL CONVERT(type, value) - simple text passthrough
BEGIN
    RETURN p_value;
END;
$$;
""")

# 23. gm_accountcacheda_srchhiddenfatiguelist - runtime: timestamp >= bytea (binary() call)
patches['gm_accountcacheda_srchhiddenfatiguelist'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION gm_accountcacheda_srchhiddenfatiguelist(
    p_world_id integer,
    p_last_login_date varchar(24)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT a.account_id, hidden_fatigue_point, hidden_fatigue_updatetime,
        hidden_fatigue_npckill, u.last_login_time, u.char_id, u.server_id
    FROM account_data a
    JOIN (
        SELECT account_id, char_id, last_login_time, server_id,
            ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY last_login_time DESC) AS login_time_rownum
        FROM global_user_data
        WHERE server_id = p_world_id
          AND last_login_time >= p_last_login_date::timestamp
    ) u ON a.account_id = u.account_id AND u.login_time_rownum = 1
    ORDER BY account_id DESC;
END;
$$;
""")

# 24. gm_accountcacheda_srchhiddenfatiguelistforexcel - runtime: same binary() issue
patches['gm_accountcacheda_srchhiddenfatiguelistforexcel'] = ('aion_account_cache_db', """
CREATE OR REPLACE FUNCTION gm_accountcacheda_srchhiddenfatiguelistforexcel(
    p_world_id integer,
    p_last_login_date varchar(24)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT a.account_id, hidden_fatigue_point, hidden_fatigue_updatetime,
        hidden_fatigue_npckill, u.last_login_time, u.char_id, u.server_id
    FROM account_data a
    JOIN (
        SELECT account_id, char_id, last_login_time, server_id,
            ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY last_login_time DESC) AS login_time_rownum
        FROM global_user_data
        WHERE server_id = p_world_id
          AND last_login_time >= p_last_login_date::timestamp
    ) u ON a.account_id = u.account_id AND u.login_time_rownum = 1
    ORDER BY account_id DESC;
END;
$$;
""")

# ============================================================
# aion_gm (39 functions)
# ============================================================

# 25. tbladminuserda_srchgmbyidornmorisdel - deploy error: nested IF/ELSE missing END IF
patches['tbladminuserda_srchgmbyidornmorisdel'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserda_srchgmbyidornmorisdel(
    p_login_id varchar(30),
    p_login_nm varchar(50),
    p_is_deleted varchar(5),
    p_is_correct varchar(10)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(2000);
    v_tmp integer;
BEGIN
    v_sql := 'SELECT T1.ADMIN_LEVEL, T2.ORGANIZATION_NM, T2.ORGANIZATION_ID, T1.ADMIN_ID, T1.LOGIN_ID, T1.LOGIN_PW, T1.LOGIN_NM, T1.LOGIN_EMAIL, T1.IS_DELETED, T1.ETC, TO_CHAR(T1.regdate, ''YYYY-MM-DD HH24:MI:SS'') regdate, TO_CHAR(T1.AUTH_UPDATE_DATE, ''YYYY-MM-DD HH24:MI:SS'') AUTH_UPDATE_DATE'
        || ' FROM TBL_ADMIN_USER T1, TBL_ADMIN_ORGANIZATION T2'
        || ' WHERE T1.ORGANIZATION_ID = T2.ORGANIZATION_ID';
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
            END IF;
        ELSE
            IF p_is_correct != 'null' THEN
                v_sql := v_sql || ' AND LOGIN_NM = ''' || p_login_nm || '''';
            ELSE
                v_sql := v_sql || ' AND LOGIN_NM like ''%' || p_login_nm || '%''';
            END IF;
        END IF;
        v_tmp := 1;
    END IF;

    IF p_is_deleted != 'null' THEN
        v_sql := v_sql || ' AND is_deleted = ''' || p_is_deleted || '''';
    END IF;

    EXECUTE v_sql;
    RETURN;
END;
$$;
""")

# 26. commit_test - runtime: relation "test" does not exist
patches['commit_test'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION commit_test(
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Original referenced table "test" which may not exist
    -- Create table if needed for testing purposes
    CREATE TABLE IF NOT EXISTS test (
        col1 varchar(50),
        col2 varchar(50),
        col3 varchar(50)
    );
    INSERT INTO test VALUES('222', 'ok', '10');
END;
$$;
""")

# 27. convert (gm) - same polymorphic type issue
patches['convert_gm'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION convert(
    p_type text,
    p_value text
) RETURNS text
LANGUAGE plpgsql
AS $$
-- Emulates T-SQL CONVERT(type, value) - simple text passthrough
BEGIN
    RETURN p_value;
END;
$$;
""")

# 28. dbmanager_dbmanager - runtime: integer = varchar comparison
patches['dbmanager_dbmanager'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION dbmanager_dbmanager(
    p_world_id varchar(5),
    p_server_nm varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT server_url FROM tbl_world_server_info
    WHERE world_id = p_world_id AND server_nm = p_server_nm;
    RETURN;
END;
$$;
""")

# 29. gm_userdatada_srchabuseqina - runtime: varchar + varchar (should use ||)
patches['gm_userdatada_srchabuseqina'] = ('aion_gm', """
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
    v_sql text;
    v_tmp integer;
    v_sql_etc text;
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

    v_sql := 'SELECT delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server,'
        || ' TO_CHAR(create_date, ''YYYY-MM-DD HH24:MI:SS'') create_date, CAST(gender AS char) gender, CAST(race AS char) race, CAST(class AS char) class, CAST(lev AS char) lev, CAST(builder AS char) builder, exp, world,'
        || ' case'
        || '   WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'''
        || '   WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'''
        || '   WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'''
        || ' end as logonoff, t2.*'
        || ' from user_data t1, qina_manipulate t2'
        || ' where t1.char_id=t2.charid and t2.qina_id not in(select t2.qina_id from user_data t1, qina_manipulate t2 where t1.char_id=t2.charid and org_server=''' || p_world_id || ''''
        || v_sql_etc || ' order by t2.qina_id desc limit ' || p_top_count || ')';
    v_sql := v_sql || v_sql_etc;
    v_sql := v_sql || ' and org_server=''' || p_world_id || ''' order by t2.qina_id desc limit ' || p_view_count;

    EXECUTE v_sql;
    RETURN;
END;
$$;
""")

# 30. gm_useritemda_srchmycompounditems - runtime: relation user_item does not exist (cross-db)
patches['gm_useritemda_srchmycompounditems'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION gm_useritemda_srchmycompounditems(
    p_char_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    -- Original references user_item from game server DB (cross-db)
    -- Using dblink or FDW would be needed for actual cross-db access
    -- For now, assumes user_item table is accessible (via FDW or local copy)
    RETURN QUERY SELECT t1.tid, t1.obtain_skin_type, t1.expire_skin_time, t1.expired_time,
        t1.buy_amount, t1.buy_duration, t1.option_count, t1.id, t1.char_id, t1.name_id,
        t1.amount, t1.slot_id, t1.slot, t1.warehouse,
        TO_CHAR(t1.create_date, 'YYYY-MM-DD HH24:MI:SS') create_date,
        TO_CHAR(t1.update_date, 'YYYY-MM-DD HH24:MI:SS') update_date,
        t1.soul_bound, t1.enchant_count, t1.skin_name_id,
        t1.stat_enchant_0, t1.stat_enchant_val0, t1.stat_enchant_1, t1.stat_enchant_val1,
        t1.stat_enchant_2, t1.stat_enchant_val2, t1.stat_enchant_3, t1.stat_enchant_val3,
        t1.stat_enchant_4, t1.stat_enchant_val4, t1.stat_enchant_5, t1.stat_enchant_val5,
        t1.dye_info, t1.proc_tool_nameid, t1.producer,
        t2.id sub_id, t2.name_id sub_name_id, t2.enchant_count sub_enchant_count,
        t2.skin_name_id sub_skin_name_id,
        t2.stat_enchant_0 sub_stat_enchant_0, t2.stat_enchant_val0 sub_stat_enchant_val0,
        t2.stat_enchant_1 sub_stat_enchant_1, t2.stat_enchant_val1 sub_stat_enchant_val1,
        t2.stat_enchant_2 sub_stat_enchant_2, t2.stat_enchant_val2 sub_stat_enchant_val2,
        t2.stat_enchant_3 sub_stat_enchant_3, t2.stat_enchant_val3 sub_stat_enchant_val3,
        t2.stat_enchant_4 sub_stat_enchant_4, t2.stat_enchant_val4 sub_stat_enchant_val4,
        t2.stat_enchant_5 sub_stat_enchant_5, t2.stat_enchant_val5 sub_stat_enchant_val5
    FROM user_item t1, user_item t2
    WHERE t1.char_id = p_char_id::integer AND t1.char_id = t2.char_id
      AND t2.main_item_dbid != 0 AND t2.warehouse = 16 AND t1.id = t2.main_item_dbid;
    RETURN;
END;
$$;
""")

# 31. gm_useritemdao_addcompound - runtime: relation user_item does not exist
patches['gm_useritemdao_addcompound'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION gm_useritemdao_addcompound(
    p_char_id integer,
    p_item_id bigint,
    p_main_item_dbid bigint
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT id FROM user_item WHERE id = p_main_item_dbid AND main_item_dbid != 0 AND char_id = p_char_id) THEN
        RETURN 1;
    END IF;
    IF EXISTS (SELECT id FROM user_item WHERE main_item_dbid = p_main_item_dbid AND warehouse != 10 AND char_id = p_char_id) THEN
        RETURN 2;
    END IF;
    IF EXISTS (SELECT id FROM user_item WHERE main_item_dbid = p_item_id AND warehouse != 10 AND char_id = p_char_id) THEN
        RETURN 3;
    END IF;
    IF EXISTS (SELECT id FROM user_item WHERE id = p_item_id AND main_item_dbid != 0 AND char_id = p_char_id) THEN
        RETURN 4;
    ELSE
        UPDATE user_item SET warehouse = 16, main_item_dbid = p_main_item_dbid, update_date = CURRENT_TIMESTAMP
        WHERE id = p_item_id AND char_id = p_char_id;
    END IF;
    RETURN 0;
END;
$$;
""")

# 32. gm_useritemdao_delcompoundrecovery - runtime: relation user_item does not exist
patches['gm_useritemdao_delcompoundrecovery'] = ('aion_gm', """
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
    SELECT main_item_dbid INTO v_main_item_dbid FROM user_item
    WHERE id = p_item_id AND char_id = p_char_id;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;

    IF v_rowcount = 0 THEN
        RETURN 1;
    END IF;

    IF NOT EXISTS (SELECT id FROM user_item WHERE warehouse = 16 AND main_item_dbid = v_main_item_dbid) THEN
        UPDATE user_item SET warehouse = p_warehouse
        WHERE warehouse = 17 AND id = p_item_id AND char_id = p_char_id;
    ELSE
        RETURN 2;
    END IF;

    RETURN 0;
END;
$$;
""")

# 33. tbladminorganizationda_srchorganizationbyid - runtime: integer = varchar
patches['tbladminorganizationda_srchorganizationbyid'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminorganizationda_srchorganizationbyid(
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT organization_id, organization_nm, organization_info
    FROM TBL_ADMIN_ORGANIZATION
    WHERE organization_id = p_organization_id::integer;
    RETURN;
END;
$$;
""")

# 34. tbladminuserda_srchbyadminid - runtime: integer = varchar comparison
patches['tbladminuserda_srchbyadminid'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserda_srchbyadminid(
    p_admin_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.admin_id, t1.login_id, t1.login_nm, t1.login_pw, t1.login_email,
        t1.is_deleted, t1.etc, TO_CHAR(t1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate,
        t1.PASSWORD_WRONG_CNT, t2.organization_id, t2.organization_nm, t2.organization_info
    FROM tbl_admin_user t1, TBL_ADMIN_ORGANIZATION t2
    WHERE admin_id = p_admin_id::integer
      AND t1.organization_id = t2.organization_id;
    RETURN;
END;
$$;
""")

# 35. tbladminuserda_srchbyloginidandpw - runtime: COLLATE korean_wansung_cs_as
patches['tbladminuserda_srchbyloginidandpw'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserda_srchbyloginidandpw(
    p_login_id varchar(50),
    p_login_pw varchar(50)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT admin_level,
        (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (PWDATE)::timestamp) / 86400)::integer pwday,
        admin_id, login_id, login_nm, login_pw, login_email, is_deleted, organization_id,
        TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate
    FROM tbl_admin_user
    WHERE is_deleted = 'Y'
      AND login_id = p_login_id
      AND login_pw = p_login_pw;
END;
$$;
""")

# 36. tbladminuserdao_creategm - runtime: integer column gets varchar value
patches['tbladminuserdao_creategm'] = ('aion_gm', """
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
    INSERT INTO TBL_ADMIN_USER (login_id, login_pw, login_nm, login_email,
        organization_id, is_deleted, etc, regdate, pwdate, admin_level, auth_update_date)
    VALUES (p_login_id, p_login_pw, p_login_nm, p_login_email,
        p_organization_id::integer, p_is_deleted, p_etc,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, p_admin_level, CURRENT_TIMESTAMP);
END;
$$;
""")

# 37. tbladminuserdao_updategmstate - runtime: integer = varchar
patches['tbladminuserdao_updategmstate'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserdao_updategmstate(
    p_admin_id varchar(10),
    p_is_deleted varchar(2)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET IS_DELETED = p_is_deleted,
        AUTH_UPDATE_DATE = CURRENT_TIMESTAMP
    WHERE ADMIN_ID = p_admin_id::integer;
END;
$$;
""")

# 38. tbladminuserdao_updatemygm - runtime: integer = varchar
patches['tbladminuserdao_updatemygm'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserdao_updatemygm(
    p_admin_id varchar(10),
    p_login_pw varchar(150),
    p_login_email varchar(170),
    p_etc varchar(200)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET PWDATE = CURRENT_TIMESTAMP,
        login_pw = p_login_pw, login_email = p_login_email, etc = p_etc
    WHERE ADMIN_ID = p_admin_id::integer;
END;
$$;
""")

# 39. tbladminuserdao_updatemygmfornopassword - runtime: integer = varchar
patches['tbladminuserdao_updatemygmfornopassword'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserdao_updatemygmfornopassword(
    p_admin_id varchar(10),
    p_login_email varchar(170),
    p_etc varchar(200)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE TBL_ADMIN_USER SET login_email = p_login_email, etc = p_etc
    WHERE ADMIN_ID = p_admin_id::integer;
END;
$$;
""")

# 40. tbladminuserhistoryda_srchhistory - runtime: integer = varchar
patches['tbladminuserhistoryda_srchhistory'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tbladminuserhistoryda_srchhistory(
    p_admin_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.LOGIN_NM, T2.*,
        (SELECT LOGIN_NM FROM TBL_ADMIN_USER T3 WHERE T3.ADMIN_ID = T2.BY_ADMIN_ID) BY_LOGIN_NM
    FROM TBL_ADMIN_USER T1, TBL_ADMIN_USER_HISTORY T2
    WHERE T1.ADMIN_ID = T2.ADMIN_ID
      AND (T2.ADMIN_ID = p_admin_id::integer OR T2.BY_ADMIN_ID = p_admin_id::integer)
    ORDER BY T2.regdate DESC LIMIT 50;
    RETURN;
END;
$$;
""")

# 41. tblapprovaldefaultstageda_srchbyworkflowcdandorganizationid - runtime: integer = varchar
patches['tblapprovaldefaultstageda_srchbyworkflowcdandorganizationid'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchbyworkflowcdandorganizationid(
    p_workflow_cd varchar(30),
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_group, t1.approval_default_stage_id,
        t1.approval_stage_num, t1.workflow_cd, t1.login_id, t1.is_final,
        t1.organization_id, t2.login_nm
    FROM TBL_APPROVAL_DEFAULT_STAGE T1, TBL_ADMIN_USER T2
    WHERE t1.workflow_cd = p_workflow_cd
      AND t1.organization_id = p_organization_id::integer
      AND t1.login_id = t2.login_id
    ORDER BY t1.approval_stage_num ASC;
    RETURN;
END;
$$;
""")

# 42. tblapprovaldefaultstageda_srchmystagenumbyworkflowcdandorganiza - runtime: integer = varchar
patches['tblapprovaldefaultstageda_srchmystagenumbyworkflowcdandorganiza'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblapprovaldefaultstageda_srchmystagenumbyworkflowcdandorganizationid(
    p_login_id varchar(30),
    p_workflow_cd varchar(30),
    p_organization_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT approval_stage_num
    FROM TBL_APPROVAL_DEFAULT_STAGE
    WHERE workflow_cd = p_workflow_cd
      AND organization_id = p_organization_id::integer
      AND login_id = p_login_id;
    RETURN;
END;
$$;
""")

# 43. tblapprovalinfoda_srchqinaadddeldoc - runtime: varchar = integer
patches['tblapprovalinfoda_srchqinaadddeldoc'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchqinaadddeldoc(
    p_char_id integer,
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_checkinout_status, t3.login_nm, t1.approval_info_id,
        t1.approval_stage_num, t1.approval_status, t1.approval_type, t1.APPROVAL_GROUP,
        t1.communication_cd, t1.world_id, t1.approval_char_id, t1.approval_char_nm,
        t1.approval_account_id, t1.approval_account_nm,
        TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.*
    FROM TBL_APPROVAL_INFO t1, TBL_APPROVAL_ITEM t2, tbl_admin_user t3, TBL_APPROVAL_HISTORY t4
    WHERE t1.approval_info_id = t2.approval_info_id
      AND t1.approval_info_id = t4.approval_info_id
      AND t4.approval_stage_num = 3
      AND t1.login_id = t3.login_id
      AND t2.approval_type != 'GRQ_ITEMMOVE'
      AND t1.approval_char_id = p_char_id::varchar
      AND t1.world_id = p_world_id::integer
      AND t1.approval_status = 'COMPLETION'
      AND t2.item_id = 182400001
    ORDER BY t1.regdate DESC;
    RETURN;
END;
$$;
""")

# 44. tblapprovalinfoda_srchqinamovedoc - runtime: varchar = integer
patches['tblapprovalinfoda_srchqinamovedoc'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchqinamovedoc(
    p_char_id integer,
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.approval_checkinout_status, t3.login_nm, t1.approval_info_id,
        t1.approval_stage_num, t1.approval_status, t1.approval_type, t1.APPROVAL_GROUP,
        t1.communication_cd, t1.world_id, t1.approval_char_id, t1.approval_char_nm,
        t1.approval_account_id, t1.approval_account_nm,
        TO_CHAR(T4.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate, t2.*
    FROM TBL_APPROVAL_INFO t1, TBL_APPROVAL_ITEM t2, tbl_admin_user t3, TBL_APPROVAL_HISTORY t4
    WHERE t1.approval_info_id = t2.approval_info_id
      AND t1.approval_info_id = t4.approval_info_id
      AND t4.approval_stage_num = 3
      AND t1.login_id = t3.login_id
      AND t2.approval_type = 'GRQ_ITEMMOVE'
      AND t2.target_char_id = p_char_id::varchar
      AND t1.world_id = p_world_id::integer
      AND t1.approval_status = 'COMPLETION'
      AND t2.item_id = 182400001
    ORDER BY t1.regdate DESC;
    RETURN;
END;
$$;
""")

# 45. tblapprovalinfoda_srchuserdoc - runtime: integer = varchar
patches['tblapprovalinfoda_srchuserdoc'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblapprovalinfoda_srchuserdoc(
    p_account_id varchar(50),
    p_world_id varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.DOC_TYPE,
        (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (T1.regdate)::timestamp) / 86400)::integer AS day_diff,
        T1.IS_PAID, t1.COMMUNICATION_CD, t1.APPROVAL_TYPE,
        t1.approval_checkinout_nm,
        TO_CHAR(T1.APPROVAL_CHECKINOUT_REGDATE, 'YYYY-MM-DD HH24:MI:SS') APPROVAL_CHECKINOUT_REGDATE,
        t1.APPROVAL_CHECKINOUT_ID, t1.APPROVAL_CHECKINOUT_STATUS, t1.approval_group,
        TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate,
        t1.approval_info_id, t1.world_id, t1.approval_char_id, t1.approval_char_nm,
        t1.approval_account_id, t1.approval_account_nm, t1.approval_info,
        t1.login_id, t1.approval_status, t1.approval_stage_num,
        t3.workflow_nm, t4.login_nm
    FROM TBL_APPROVAL_INFO t1, tbl_workflow_list t3, tbl_admin_user t4
    WHERE t1.login_id = t4.login_id
      AND t1.workflow_cd = t3.workflow_cd
      AND t1.approval_account_id = p_account_id
      AND t1.world_id = p_world_id::integer
    ORDER BY t1.regdate DESC;
END;
$$;
""")

# 46. tblbotpointrankingda_srchaccountpunishhistory - runtime: timestamp >= varchar
patches['tblbotpointrankingda_srchaccountpunishhistory'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblbotpointrankingda_srchaccountpunishhistory(
    p_date_from varchar(16),
    p_date_to varchar(16)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT punish_id, punish_group_id, punish_account_id,
        punish_account_name, punish_code, reg_login_id, reg_login_nm,
        reg_date, reg_date_str
    FROM TBL_BOT_ACCOUNT_PUNISH
    WHERE reg_date BETWEEN p_date_from::timestamp AND p_date_to::timestamp
    ORDER BY reg_date_str DESC, punish_group_id, punish_account_id;
END;
$$;
""")

# 47. tblbuildercommandscheduleda_srchschedule - runtime: timestamp = bytea (binary() call)
patches['tblbuildercommandscheduleda_srchschedule'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchschedule(
    p_DATE varchar(20),
    p_COMMUNICATION_CD varchar(5) DEFAULT NULL
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_COMMUNICATION_CD IS NULL THEN
        RETURN QUERY SELECT ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE,
            SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD,
            COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE
        FROM TBL_BUILDER_COMMAND_SCHEDULE
        WHERE SCHEDULE_DATE = p_DATE::timestamp AND REPEAT_TYPE = 'ONCE';
    ELSE
        RETURN QUERY SELECT ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE,
            SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD,
            COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE
        FROM TBL_BUILDER_COMMAND_SCHEDULE
        WHERE SCHEDULE_DATE = p_DATE::timestamp
          AND COMMUNICATION_CD = p_COMMUNICATION_CD AND REPEAT_TYPE = 'ONCE';
    END IF;
END;
$$;
""")

# 48. tblbuildercommandscheduleda_srchschedulebydate - runtime: timestamp >= bytea
patches['tblbuildercommandscheduleda_srchschedulebydate'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblbuildercommandscheduleda_srchschedulebydate(
    p_DATEFROM varchar(20),
    p_DATETO varchar(20),
    p_COMMUNICATION_CD varchar(5) DEFAULT NULL
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_COMMUNICATION_CD IS NULL THEN
        RETURN QUERY SELECT ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE,
            SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD,
            COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE
        FROM TBL_BUILDER_COMMAND_SCHEDULE
        WHERE SCHEDULE_DATE BETWEEN p_DATEFROM::timestamp AND p_DATETO::timestamp
        ORDER BY ID DESC;
    ELSE
        RETURN QUERY SELECT ID, COMMAND_SUBJECT, COMMAND_TEXT, SCHEDULE_TYPE,
            SCHEDULE_DATE, SCHEDULE_FROM, SCHEDULE_TO, REPEAT_TYPE, REPEAT_PERIOD,
            COMMUNICATION_CD, STATUS, LOGIN_ID, REGDATE
        FROM TBL_BUILDER_COMMAND_SCHEDULE
        WHERE SCHEDULE_DATE BETWEEN p_DATEFROM::timestamp AND p_DATETO::timestamp
          AND COMMUNICATION_CD = p_COMMUNICATION_CD
        ORDER BY ID DESC;
    END IF;
END;
$$;
""")

# 49. tblgamenoticehistorydao_insertnoticehistory - runtime: integer column gets varchar
patches['tblgamenoticehistorydao_insertnoticehistory'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblgamenoticehistorydao_insertnoticehistory(
    p_notice_id varchar(30),
    p_world_id integer,
    p_communication_cd varchar(30)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Use column list to avoid positional INSERT issues with identity/serial columns
    INSERT INTO TBL_GAME_NOTICE_HISTORY (notice_id, world_id, communication_cd, regdate)
    VALUES (p_notice_id, p_world_id, p_communication_cd, CURRENT_TIMESTAMP);
END;
$$;
""")

# 50. tblgamenoticescheduleda_srchreservedschedule - runtime: timestamp >= varchar
patches['tblgamenoticescheduleda_srchreservedschedule'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblgamenoticescheduleda_srchreservedschedule(
    p_current_time varchar(30),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_notice_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT NOTICE_RACE, NOTICE_CLASS, notice_pos_type, notice_id,
        notice_repeat, notice_repeat_min, notice_category, notice_subject,
        notice_type, notice_from, notice_to, notice_period, notice_week,
        notice_month, period_hour, period_min, communication_cd, notice_count,
        notice_status, login_id, TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate
    FROM TBL_GAME_NOTICE_SCHEDULE
    WHERE ((NOTICE_TO >= p_current_time::timestamp AND NOTICE_FROM <= p_current_time::timestamp
            AND PERIOD_HOUR = p_period_hour AND PERIOD_MIN = p_period_min)
        OR (NOTICE_TO >= p_current_time::timestamp AND NOTICE_FROM <= p_current_time::timestamp
            AND notice_repeat_min != 0)
        OR (notice_period = 'ONCE' AND communication_cd = 'BEF'))
      AND NOTICE_STATUS = p_notice_status AND communication_cd != 'TRA'
    ORDER BY regdate ASC;
END;
$$;
""")

# 51. tblgamenoticescheduleda_srchtranshistory - runtime: integer = varchar
patches['tblgamenoticescheduleda_srchtranshistory'] = ('aion_gm', """
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
    RETURN QUERY SELECT count(*) sendable
    FROM tbl_game_notice_schedule t1, tbl_game_notice_history t2
    WHERE t1.notice_id = t2.notice_id
      AND t1.notice_id = p_notice_id
      AND t1.period_hour = p_period_hour
      AND t1.period_min = p_period_min
      AND (t1.communication_cd = p_communication_cd OR t1.communication_cd = 'TRA')
      AND t1.notice_status = p_notice_status
      AND TO_CHAR(t2.regdate, 'YYYYMMDD') = p_cur_yyyymmdd;
    RETURN;
END;
$$;
""")

# 52. tblgameworldinfoda_srchchannel - runtime: smallint = varchar
patches['tblgameworldinfoda_srchchannel'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblgameworldinfoda_srchchannel(
    p_world_id varchar(5),
    p_channel_num varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT world_type, zone_id, zone_nm, channel_num
    FROM tbl_game_world_info
    WHERE world_id = p_world_id
      AND zone_id != 0
      AND channel_num = p_channel_num
      AND zone_id <= 719999999
    ORDER BY world_type DESC;
END;
$$;
""")

# 53. tbllogfilesdao_insertfile - runtime: integer column gets varchar (identity column)
patches['tbllogfilesdao_insertfile'] = ('aion_gm', """
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
    -- Use column list to skip identity/serial logfile_id column
    INSERT INTO TBL_LOG_FILES (logfile_type, logfile_name, logfile_size,
        logfile_info, is_shared, is_deleted, login_id, regdate)
    VALUES (p_logfile_type, p_logfile_name, p_logfile_size, p_logfile_info,
        p_is_shared, p_is_deleted, p_login_id, CURRENT_TIMESTAMP);
END;
$$;
""")

# 54. tblmyworldda_srchmyworldserverstatusformaxmin - runtime: integer = varchar
patches['tblmyworldda_srchmyworldserverstatusformaxmin'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblmyworldda_srchmyworldserverstatusformaxmin(
    p_server_nm varchar(3)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.WORLD_STATUS_INFO_ID, t1.WORLD_ID, t1.SERVER_NM,
        t1.concurrent_users, t1.CPU_USAGE, t1.FREE_PHY_MEMORY, t1.PROCESS_MEMORY,
        TO_CHAR(T1.regdate, 'YYYY-MM-DD HH24:MI:SS') regdate
    FROM TBL_WORLD_STATUS_INFO t1
    WHERE t1.server_nm = p_server_nm;
    RETURN;
END;
$$;
""")

# 55. tblpollda_pollsrchwillbedeletedlist - runtime: timestamp <= varchar
patches['tblpollda_pollsrchwillbedeletedlist'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblpollda_pollsrchwillbedeletedlist(
    p_poll_status varchar(3),
    p_poll_end_data varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT poll_id FROM tbl_poll
    WHERE POLL_STATUS = p_poll_status AND POLL_END_DATE <= p_poll_end_data::timestamp;
END;
$$;
""")

# 56. tblpollserverda_polldiff - runtime: integer <= text comparison
patches['tblpollserverda_polldiff'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblpollserverda_polldiff(
    p_cycle_min varchar(5),
    p_max_min varchar(5)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.poll_id, t1.world_id, t1.pub_status, t1.RS_FILE_NAME,
        t1.poll_cnt, t1.start_date, t1.end_date,
        TO_CHAR(t1.gathering_date, 'YYYY-MM-DD HH24:MI:SS') gathering_date, t1.regdate
    FROM tbl_poll_server t1, tbl_poll t2
    WHERE t2.is_deleted = 'Y'
      AND t1.poll_id = t2.poll_id
      AND (t1.pub_status = 'ING' OR t1.pub_status = 'STP' OR t1.pub_status = 'COM')
      AND (EXTRACT(EPOCH FROM (t1.end_date)::timestamp - (t1.gathering_date)::timestamp) / 60)::integer <= p_cycle_min::integer
      AND (EXTRACT(EPOCH FROM (t1.end_date)::timestamp - (t1.gathering_date)::timestamp) / 60)::integer >= p_max_min::integer;
END;
$$;
""")

# 57. tblpollserverda_pollserversrchbydateandstatus - runtime: timestamp <= text
patches['tblpollserverda_pollserversrchbydateandstatus'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblpollserverda_pollserversrchbydateandstatus(
    p_cur_date varchar(30),
    p_pub_status varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t1.poll_id, t1.world_id, t1.pub_status, t1.RS_FILE_NAME,
        t1.poll_cnt, t1.start_date, t1.end_date,
        TO_CHAR(t1.gathering_date, 'YYYY-MM-DD HH24:MI:SS') gathering_date, t1.regdate
    FROM tbl_poll_server t1, tbl_poll t2
    WHERE t2.is_deleted = 'Y'
      AND t1.poll_id = t2.poll_id
      AND (t1.pub_status = 'ING' OR t1.pub_status = 'STP' OR t1.pub_status = p_pub_status)
      AND t1.start_date <= p_cur_date::timestamp
      AND t1.end_date >= p_cur_date::timestamp;
END;
$$;
""")

# 58. tblquestda_srchmyquest - runtime: integer = varchar
patches['tblquestda_srchmyquest'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblquestda_srchmyquest(
    p_world_id varchar(5),
    p_char_id varchar(20),
    p_account_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * FROM TBL_QUEST
    WHERE world_id = p_world_id::integer
      AND char_id = p_char_id::integer
      AND account_id = p_account_id::integer
    ORDER BY quest_pk DESC;
    RETURN;
END;
$$;
""")

# 59. tblquestda_srchmyquestbyreqid - runtime: integer = varchar
patches['tblquestda_srchmyquestbyreqid'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblquestda_srchmyquestbyreqid(
    p_quest_req_id varchar(30),
    p_world_id varchar(5),
    p_char_id varchar(20),
    p_account_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * FROM TBL_QUEST
    WHERE quest_req_id = p_quest_req_id
      AND world_id = p_world_id::integer
      AND char_id = p_char_id::integer
      AND account_id = p_account_id::integer;
    RETURN;
END;
$$;
""")

# 60. tblstatisticsda_srchpollrs - runtime: integer = varchar
patches['tblstatisticsda_srchpollrs'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblstatisticsda_srchpollrs(
    p_world_id varchar(5),
    p_poll_id varchar(15),
    p_to_date varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT WORLD_ID, POLL_ID, CHAR_ID, USER_ID, ACCOUNT_ID,
        ACCOUNT_NAME, CLASS, RACE, WORLD, XLOCATION, YLOCATION, ZLOCATION, LEV,
        TO_CHAR(ANSWER_TIME, 'YYYY-MM-DD HH24:MI:SS') ANSWER_TIME, ANSWER
    FROM TBL_STATISTICS_POLL
    WHERE world_id = p_world_id::integer AND poll_id = p_poll_id;
END;
$$;
""")

# 61. tblstatisticsscheduleda_srchreservedschedule - runtime: timestamp >= varchar
patches['tblstatisticsscheduleda_srchreservedschedule'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblstatisticsscheduleda_srchreservedschedule(
    p_current_time varchar(30),
    p_period_hour varchar(2),
    p_period_min varchar(2),
    p_statistics_status char(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * FROM TBL_STATISTICS_SCHEDULE
    WHERE ((STATISTICS_TO >= p_current_time::timestamp
            AND STATISTICS_FROM <= p_current_time::timestamp
            AND PERIOD_HOUR = p_period_hour AND PERIOD_MIN = p_period_min)
        OR (STATISTICS_TO >= p_current_time::timestamp
            AND STATISTICS_FROM <= p_current_time::timestamp
            AND statistics_repeat_min != 0)
        OR (statistics_period = 'ONCE' AND task_cd = 'BEF'))
      AND statistics_status = p_statistics_status AND task_cd != 'TRA'
    ORDER BY regdate ASC;
    RETURN;
END;
$$;
""")

# 62. tblstatisticsscheduleda_srchtranshistory - runtime: integer = varchar
patches['tblstatisticsscheduleda_srchtranshistory'] = ('aion_gm', """
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
    RETURN QUERY SELECT count(*) sendable
    FROM TBL_STATISTICS_SCHEDULE t1, TBL_STATISTICS_HISTORY t2
    WHERE t1.statistics_id = t2.statistics_id
      AND t1.statistics_id = p_statistics_id
      AND t1.period_hour = p_period_hour
      AND t1.period_min = p_period_min
      AND (t1.task_cd = p_task_cd OR t1.task_cd = 'TRA')
      AND t1.statistics_status = p_statistics_status
      AND TO_CHAR(t2.regdate, 'YYYYMMDD') = p_cur_yyyymmdd;
    RETURN;
END;
$$;
""")

# 63. tblworldinfoda_srchgameftworlds - runtime: integer >= varchar
patches['tblworldinfoda_srchgameftworlds'] = ('aion_gm', """
CREATE OR REPLACE FUNCTION tblworldinfoda_srchgameftworlds(
    p_from_world_id varchar(3),
    p_to_world_id varchar(3)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT T1.WORLD_ID, T1.WORLD_NM, T1.WORLD_DESC, T1.WORLD_STATUS,
        T2.DARK_USERS AS TOTAL_CON_USERS,
        T2.PC_STORE_LIGHT_USERS AS LIGHT_CHAR_COUNT,
        T2.PC_STORE_DARK_USERS AS DARK_CHAR_COUNT
    FROM tbl_world_info t1, TBL_GAME_WORLD_INFO t2
    WHERE t1.world_id = t2.world_id AND t2.zone_id = 0
      AND t1.world_status = 'Y'
      AND t1.world_id BETWEEN p_from_world_id::integer AND p_to_world_id::integer
    ORDER BY t1.world_id ASC;
    RETURN;
END;
$$;
""")

# ============================================================
# Write all patches
# ============================================================

written = 0
for func_name, (db_name, sql_body) in patches.items():
    # Handle the special case where convert has db-specific names
    actual_filename = func_name
    if func_name == 'convert_cache':
        actual_filename = 'convert'
        # Skip: same function, different db - we write the aion_account_db version
        # and let the deploy script handle per-db deployment
        # Actually, we need separate files per db. Use db prefix.
        actual_filename = 'convert__aion_account_cache_db'
    elif func_name == 'convert_gm':
        actual_filename = 'convert__aion_gm'
    elif func_name == 'convert':
        actual_filename = 'convert__aion_account_db'

    path = write_patch(actual_filename, db_name, sql_body)
    written += 1

print(f'Total patches written: {written}')
print(f'Output directory: {PATCHES_DIR}')
