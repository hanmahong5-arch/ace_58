-- ============================================================
-- PL/pgSQL Functions converted from AionAccountDB
-- Source: AionAccountDB_schema.json
-- Total: 52 procedures
-- Auto-converted: 43
-- Needs review: 9
-- Needs manual work: 0
-- ============================================================

-- Confidence Legend:
--   [AUTO]   - Fully automatic conversion
--   [REVIEW] - Likely correct, please verify
--   [MANUAL] - Needs human intervention

-- [OK] [AUTO] ap_TEST_ModifyPackageVersionInfo

CREATE OR REPLACE FUNCTION ap_test_modifypackageversioninfo(
    p_account varchar(14),
    p_version integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_result integer;
BEGIN
    v_result := 0;
    UPDATE AccountETC SET packageVersionInfo=p_version FROM AccountAuth AA INNER JOIN AccountETC AE ON (AA.gameAccountNo = AE.gameAccountNo) WHERE AA.gameAccount=p_account;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount <> 1 THEN
    v_result := 1;
    END IF;
    RETURN v_result;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] pap_CreateAccount
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION pap_createaccount(
    p_gameAccountNo integer,
    p_gameAccount varchar(16),
    p_password bytea,
    p_crytographTypeCode smallint,
    p_birthday timestamp,
    p_genderCode smallint
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_originalPassword varchar(16);
    v_ret integer;
    v_authLimitTypeBitSet integer;
BEGIN
    v_ret := 0;
    v_authLimitTypeBitSet := 1;
    -- Transaction managed by PG function context
    INSERT INTO AccountAuth (gameAccountNo, gameAccount, password, cryptographTypeCode, legalBirthday, genderCode, authLimitTypeBitSet) VALUES (p_gameAccountNo, p_gameAccount, p_password, p_crytographTypeCode, p_birthday, p_genderCode, v_authLimitTypeBitSet);
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_ret := 1;
    -- TODO: MANUAL REVIEW NEEDED - GOTO FIN
    RETURN NULL;  -- Originally: GOTO FIN
    END IF;
    INSERT INTO AccountETC (gameAccountNo) VALUES (p_gameAccountNo);
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_ret := 2;
    -- TODO: MANUAL REVIEW NEEDED - GOTO FIN
    RETURN NULL;  -- Originally: GOTO FIN
    END IF;
    -- COMMIT (implicit in PG function)
    RETURN v_ret;
    -- Label: FIN
    RAISE EXCEPTION 'Rollback requested';
    RETURN v_ret;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] pap_GetAccount

CREATE OR REPLACE FUNCTION pap_getaccount(
    p_account varchar(14),
    OUT p_uid integer,
    OUT p_password bytea,
    OUT p_passwordFlag smallint,
    OUT p_birthdate timestamp,
    OUT p_sex smallint,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    p_uid := 0;
    p_password := 0;
    p_passwordFlag := 0;
    p_birthdate := '19700101';
    p_sex := 0;
    SELECT gameAccountNo, password, cryptographTypeCode, legalBirthday, genderCode INTO p_uid, p_password, p_passwordFlag, p_birthdate, p_sex FROM AccountAuth WHERE	gameAccount = p_account;
    IF p_uid = 0 THEN
    p_return_code := 2;
    RETURN;
    END IF;
    p_return_code := 0;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] pap_GetAccountByUserId

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
    v_ret integer;
BEGIN
    p_account := '';
    SELECT gameAccount INTO p_account FROM AccountAuth WHERE	gameAccountNo = p_uid;
    IF p_account = '' THEN
    p_return_code := 2;
    RETURN;
    END IF;
    v_ret := pap_GetAccount(p_account, p_uid, p_password, p_passwordFlag, p_birthdate, p_sex);
    p_return_code := 0;
        -- RETURN_EXPR: v_ret;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] pap_GetGameInfo

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
    v_isNoticed boolean;
    v_isRestricted boolean;
    v_isSecurityServiceUsed boolean;
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
    SELECT gameAccount, accountStatusCode, 0, COALESCE(fn_ap_GetBlockFlag (gameAccountNo, accountStatusCode),0), 1, noticeFlag, restrictFlag, 1 INTO p_account, p_statusFlag, p_activeFlag, p_blockFlag, v_exist, v_isNoticed, v_isRestricted, v_isSecurityServiceUsed FROM AccountAuth WHERE	gameAccountNo = p_uid LIMIT 1;
    IF v_isNoticed = 1 THEN
    p_warnStat := COALESCE(fn_ap_GetWarnFlag (p_uid, v_isNoticed, CURRENT_TIMESTAMP),0);
    END IF;
    IF v_isRestricted = 1 THEN
    p_blockFlag2 := COALESCE(fn_ap_GetBlockFlag2 (p_uid, v_isRestricted, CURRENT_TIMESTAMP), 0);
    END IF;
    IF v_isSecurityServiceUsed = 1 THEN
    SELECT accountsecuritystatuscode INTO p_otpStat FROM accountsecurityservice WHERE  gameaccountno = p_uid AND accountsecuritymethodcode = 1;
    SELECT accountsecuritystatuscode INTO p_macStat FROM accountsecurityservice WHERE  gameaccountno = p_uid AND accountsecuritymethodcode = 2;
    END IF;
    IF (v_exist = 1) THEN
    p_return_code := 0;
    RETURN;
    END IF;
    p_return_code := 2;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] pap_GetNewAccountNo

CREATE OR REPLACE FUNCTION pap_getnewaccountno(
    OUT p_gameAccountNo integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    p_gameAccountNo := 0;
    INSERT INTO AccountNo DEFAULT VALUES;
    p_gameAccountNo := LASTVAL();
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] pap_UpdateAccount

CREATE OR REPLACE FUNCTION pap_updateaccount(
    p_gameAccountNo integer,
    p_password bytea
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_originalPassword bytea;
BEGIN
    SELECT password INTO v_originalPassword FROM AccountAuth WHERE	gameAccountNo = p_gameAccountNo;
    IF v_originalPassword != p_password THEN
    UPDATE AccountAuth SET password = p_password WHERE gameAccountNo = p_gameAccountNo;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    RETURN 2;
    END IF;
    RETURN 0;
    END IF;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] write_gameuser_counts

CREATE OR REPLACE FUNCTION write_gameuser_counts(
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_gamename varchar(50);
    v_cnt integer;
    v_txt varchar(500);
    v_FS integer;
    v_OLEResult integer;
    v_FileID integer;
BEGIN
    v_gamename := 'AION';
    v_txt := 'OK|';
    v_cnt := ( select sum(concurrentUserCount) from ConcurrentUserStat where serverNo=0 and concurrentUserStatTypeCode=2 and registerdate > (CURRENT_TIMESTAMP + INTERVAL '-5 minutes') group by serverNo );
    v_txt := v_txt || v_gamename || '=' || CAST(v_cnt AS varchar(10)) || '; ';
    v_OLEResult := sp_OACreate('Scripting.FileSystemObject', v_FS);
    IF v_OLEResult <> 0 THEN
        RAISE NOTICE '%', 'Error: Scripting.FileSystemObject';
    END IF;
    v_OLEResult := sp_OAMethod(v_FS, 'OpenTextFile', v_FileID, 'c:\game_counts.txt', 2, 1);
    IF v_OLEResult <>0 THEN
        RAISE NOTICE '%', 'Error: OpenTextFile';
    END IF;
    v_OLEResult := sp_OAMethod(v_FileID, 'Write', Null, v_txt);
    IF v_OLEResult <> 0 THEN
        RAISE NOTICE '%', 'Error : Write';
    END IF;
    v_OLEResult := sp_OADestroy(v_FileID);
    v_OLEResult := sp_OADestroy(v_FS);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetGameServerChargeGroupList

CREATE OR REPLACE FUNCTION aop_getgameserverchargegrouplist(
    p_unknown text
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	gameServerNo, gameServerChargeGroupNo FROM	SN.GameServerChargeGroup ORDER BY gameServerNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] PAServer_GetAccount

CREATE OR REPLACE FUNCTION paserver_getaccount(
    p_account varchar(14)
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM gameAccountNo		as account_id ,gameAccount				as account_name ,password					as password ,cryptographTypeCode		as psw_type_code ,legalBirthday				as birth_day ,genderCode				as gender ,gameAccountTypeCode	as account_type_code ,gameAccountGradeCode	as grade_code ,accountStatusCode		as status_code ,authLimitTypeBitSet		as block_code ,securityServiceFlag			as security_flag ,restrictFlag				as restrict_flag ,noticeFlag					as notice_flag ,hardwareId				as hardward_id FROM AccountAuth where gameAccount = p_account;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] account_InPut

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
    v_legalBirthday := '1900-01-01 00:00:00:000';
    v_account_name := '_sd_0000000_';
    PERFORM pap_GetAllianceCompanyAccount p_allianceUserKey,27,4,v_accountNo,v_genderCode,v_legalBirthday,v_retCode);
    IF v_accountNo=0 and v_retCode=2 THEN
    v_accountno := 0;
    PERFORM pap_GetNewAccountNo v_accountno);
    IF v_accountno < 10000000 THEN
    v_account_name := '_sd_' || right('00000000' || CAST(v_accountno AS varchar),7) || '_';
    ELSE
    v_account_name := '_sd_' || CAST(v_accountno AS varchar) || '_';
    END IF;
    PERFORM pap_CreateAccount v_accountno,v_account_name,123594147596486815314808548425616416800,2,'1970-01-01 00:00:00:000',1);
    v_retCode := 0;
    PERFORM pap_CreateAllianceCompanyAccount p_allianceUserKey,27,v_accountno,4,1,'1970-01-01 00:00:00:000',v_retCode);
    ELSE
    v_account_name := (select gameaccount from AccountAuth where gameaccountno in (select accountno from AllianceCompanyAccount where allianceUserKey=p_allianceUserKey));
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetAccountInfo

CREATE OR REPLACE FUNCTION aop_getaccountinfo(
    p_account varchar(16),
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_ncotp_flag integer;
    v_mcontrol_flag integer;
    v_pcregister_flag integer;
    v_uid integer;
BEGIN
    PERFORM AA.gameAccountNo, AE.accountCreateDate, AE.lastLoginDate, AE.lastLogoutDate , AA.accountStatusCode, AA.noticeFlag, AA.restrictFlag, AA.genderCode , AA.gameAccountTypeCode, AA.gameAccountGradeCode, AA.authLimitTypeBitSet FROM accountAuth AA INNER JOIN accountEtc AE ON AA.gameAccountNo = AE.gameAccountNo WHERE AA.gameAccount = p_account;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ErrorCode := 0150201010;
    RETURN;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetAccountNoticeList

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
    SELECT gameAccountNo INTO v_uid FROM AccountAuth where gameAccount = p_account;
    PERFORM ALN.gameAccountNo, ALN.noticeTypeCode, CC.codeName, ALN.noticeStartDate, ALN.noticeEndDate FROM accountLoginNotice ALN , commondb.commonCode CC WHERE ALN.gameAccountNo = v_uid AND CC.codeGroupNo = v_noticeCodeGroupNo AND CC.code = ALN.noticeTypeCode;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ErrorCode := 0150201010;
    RETURN;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetBlockCount

CREATE OR REPLACE FUNCTION aop_getblockcount(
    p_account varchar(20),
    OUT p_totalCount integer,
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*) INTO p_totalCount FROM Restriction RT INNER JOIN accountAuth AA ON AA.gameAccountNo = RT.gameAccountNo WHERE AA.gameAccount = p_account;
    p_ErrorCode := 0;
    p_return_code := p_ErrorCode;
    RETURN;
    -- Label: ErrorHandler
    PERFORM p_ErrorCode;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetBlockHistoryList

CREATE OR REPLACE FUNCTION aop_getblockhistorylist(
    p_account varchar(16),
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_uid integer;
BEGIN
    PERFORM R.gameRestrictionNo, R.gameAccountNo, R.gameRestrictionReasonCode, R.restrictionStartDate , R.restrictionEndDate, R.restrictionExpireDate FROM Restriction R, accountAuth AA WHERE AA.gameAccount = p_account AND AA.gameAccountNo = R.gameAccountNo ORDER BY restrictionStartDate DESC;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ErrorCode := 0150201010;
    RETURN;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_GetBlockList
--   Warning: sp_executesql converted to EXECUTE - may need manual USING clause

CREATE OR REPLACE FUNCTION aop_getblocklist(
    p_account varchar(20),
    p_pageSize integer,
    p_pageNumber integer,
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_sql varchar(4000);
    v_ExcludePage integer;
BEGIN
    v_ExcludePage := p_pageSize * p_pageNumber;
    v_sql := ' SELECT TOP ' || CAST(p_pageSize AS varchar) || '  RT.gameRestrictionNo , RT.gameAccountNo , RT.gameRestrictionReasonCode , RT.restrictionStartDate , RT.restrictionEndDate , RT.restrictionExpireDate FROM Restriction RT INNER JOIN accountAuth AA ON AA.gameAccountNo = RT.gameAccountNo WHERE AA.gameAccount = ''' || p_account || ''' AND RT.gameRestrictionNo < ( SELECT COALESCE(MIN(DV.gameRestrictionNo), 99999999) FROM ( SELECT TOP ' || CAST(v_ExcludePage AS varchar) || '  RT.gameRestrictionNo FROM Restriction RT INNER JOIN accountAuth AA ON AA.gameAccountNo = RT.gameAccountNo WHERE AA.gameAccount = ''' || p_account || ''' ORDER BY RT.gameRestrictionNo DESC ) DV ) ORDER BY RT.gameRestrictionNo DESC ';
    EXECUTE v_sql;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ErrorCode := 0150201010;
    RETURN;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetGameServerList

CREATE OR REPLACE FUNCTION aop_getgameserverlist(
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_ncotp_flag integer;
    v_mcontrol_flag integer;
    v_pcregister_flag integer;
    v_uid integer;
BEGIN
    PERFORM gameServerNo, gameServerName, gameServerTypeCode, gameServerStatusCode, serverAreaCode , userAgeLimit, privateNetworkIPAddress, publicNetworkIPAddress, portNo, paidFlag, serverCustomizeBitSet FROM GameServer;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_ErrorCode := 0150201010;
    RETURN;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] aop_GetNCTASStatus

CREATE OR REPLACE FUNCTION aop_getnctasstatus(
    p_gameAccount varchar(16),
    OUT p_accountSecurityStatusCode integer,
    OUT p_ErrorCode integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_accountSecurityMethodCode smallint;
BEGIN
    v_accountSecurityMethodCode := 5;
    SELECT COALESCE(ASS.accountSecurityStatusCode,0) INTO p_accountSecurityStatusCode FROM AccountAuth AA INNER JOIN AccountSecurityService ASS ON ASS.gameAccountNo = AA.gameAccountNo WHERE AA.gameAccount = p_gameAccount AND accountSecurityMethodCode = v_accountSecurityMethodCode;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    p_accountSecurityStatusCode := 0;
    END IF;
    p_ErrorCode := 000;
    p_return_code := 0;
    RETURN;
    -- Label: ErrorHandler
    p_return_code := p_ErrorCode;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_ModifyAccountType
--   Warning: GOTO statements detected - converted to RETURN where possible

CREATE OR REPLACE FUNCTION aop_modifyaccounttype(
    p_gameAccount varchar(16),
    p_typeCode smallint
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_retcode integer;
    v_retmsg varchar(1024);
    v_gameAccountNo integer;
BEGIN
    SELECT gameAccountNo INTO v_gameAccountNo FROM accountAuth WHERE gameAccount = p_gameAccount;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_retcode := -17;
    v_retmsg := '秦寸 拌沥捞 粮犁窍瘤 臼嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_ERROR
    RETURN NULL;  -- Originally: GOTO END_ERROR
    END IF;
    IF p_typeCode = 1 THEN
    UPDATE AccountAuth Set gameAccountTypeCode = 1, authLimitTypeBitSet = 1 WHERE gameAccount = p_gameAccount;
    ELSIF p_typeCode = 2 THEN
    UPDATE AccountAuth Set gameAccountTypeCode = 2, authLimitTypeBitSet = 2 WHERE gameAccount = p_gameAccount;
    ELSIF p_typeCode = 3 THEN
    UPDATE AccountAuth Set gameAccountTypeCode = 1, authLimitTypeBitSet = 0 WHERE gameAccount = p_gameAccount;
    ELSE
    v_retcode := -1;
    v_retmsg := '瘤盔窍瘤 臼绰 拌沥蜡屈涝聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_ERROR
    RETURN NULL;  -- Originally: GOTO END_ERROR
    END IF;
    IF 0 /* @v_ERROR */ = 0 THEN
    v_retcode := 0;
    v_retmsg := '己傍';
    END IF;
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    -- Label: END_ERROR
    RAISE NOTICE '%', v_retcode;
    IF v_retcode IS NULL THEN
    v_retcode := -999;
    v_retmsg := '舅荐 绝绰 俊矾啊 惯积沁嚼聪促.';
    END IF;
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_ModifyBlockAdd
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION aop_modifyblockadd(
    p_gameAccount varchar(16),
    p_restrictionReasonCode smallint,
    p_restrictionEndDate timestamp,
    OUT p_restrictionNo integer,
    OUT p_return_code integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_retcode integer;
    v_retmsg varchar(1024);
    v_gameAccountNo integer;
BEGIN
    p_restrictionNo := -1;
    SELECT gameAccountNo INTO v_gameAccountNo FROM accountAuth WHERE gameAccount = p_gameAccount;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_retcode := -17;
    v_retmsg := '秦寸 拌沥捞 粮犁窍瘤 臼嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) FROM   Restriction WHERE gameAccountNo = v_gameAccountNo AND restrictionEndDate > CURRENT_TIMESTAMP AND gameRestrictionReasonCode = p_restrictionReasonCode) > 0 THEN
    v_retcode := -12;
    v_retmsg := '秦寸 拌沥捞 鞍篮 荤蜡肺 捞固 力犁登绢 乐嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    -- Transaction managed by PG function context
    INSERT INTO Restriction ( gameAccountNo, gameRestrictionReasonCode, restrictionStartDate, restrictionEndDate, restrictionExpireDate) VALUES ( v_gameAccountNo, p_restrictionReasonCode, CURRENT_TIMESTAMP, p_restrictionEndDate, p_restrictionEndDate);
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN;  -- Originally: GOTO END_ROLLBACK
    END IF;
    p_restrictionNo := LASTVAL();
    UPDATE AccountAuth SET  restrictFlag = 1 where gameAccountNo = v_gameAccountNo;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN;  -- Originally: GOTO END_ROLLBACK
    END IF;
    v_retcode := 1;
    v_retmsg := '秦寸 拌沥捞 力犁登菌嚼聪促.';
    -- COMMIT (implicit in PG function)
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN;
    -- Label: END_ROLLBACK
    RAISE NOTICE '%', @v_TRANCOUNT;
    IF @v_TRANCOUNT > 0 THEN
    RAISE NOTICE '%', 'didrollback';
    RAISE EXCEPTION 'Rollback requested';
    END IF;
    IF v_retcode IS NOT NULL THEN
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    END IF;
    RETURN;
    -- Label: END_NO_ROLLBACK
    RAISE NOTICE '%', v_retcode;
    IF v_retcode IS NULL THEN
    v_retcode := -999;
    v_retmsg := '舅荐 绝绰 俊矾啊 惯积沁嚼聪促.';
    END IF;
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN;
    p_return_code := 0;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_ModifyBlockRemove
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION aop_modifyblockremove(
    p_gameRestrictionNo integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_retcode integer;
    v_gameAccountNo integer;
    v_gameAccount varchar(16);
    v_retmsg varchar(1024);
BEGIN
    SELECT gameAccountNo INTO v_gameAccountNo FROM Restriction NOLOCK WHERE gameRestrictionNo = p_gameRestrictionNo;
    IF 0 /* @v_ERROR */ <> 0 THEN
    v_retcode := -7;
    v_retmsg := '秦寸 力犁 沥焊甫 啊廉坷绰 窜拌俊辑 俊矾啊 惯积沁嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    IF v_gameAccountNo IS NULL OR LENGTH(v_gameAccount) = 0 THEN
    v_retcode := -101;
    v_retmsg := '秦寸 拌沥捞 绝嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    -- Transaction managed by PG function context
    UPDATE Restriction SET restrictionEndDate = CURRENT_TIMESTAMP WHERE gameRestrictionNo = p_gameRestrictionNo;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) WHERE gameAccountNo = v_gameAccountNo AND restrictionEndDate > CURRENT_TIMESTAMP) = 0 THEN
    UPDATE AccountAuth SET restrictFlag = 0 WHERE gameAccountNo = v_gameAccountNo;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    END IF;
    v_retcode := 1;
    v_retmsg := '秦寸 拌沥狼 力犁啊 秦瘤 登菌嚼聪促.';
    -- COMMIT (implicit in PG function)
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    -- Label: END_ROLLBACK
    RAISE EXCEPTION 'Rollback requested';
    RETURN NULL;
    -- Label: END_NO_ROLLBACK
    IF v_retcode IS NULL THEN
    RETURN NULL;
    END IF;
    v_retcode := -999;
    v_retmsg := '舅荐 绝绰 俊矾啊 惯积沁嚼聪促.';
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_ModifyChangeLogInFlag
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION aop_modifychangeloginflag(
    p_gameAccount varchar(16),
    p_noticeTypeCode smallint,
    p_noticeEndDate timestamp
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_retcode integer;
    v_retmsg varchar(1024);
    v_gameAccountNo integer;
BEGIN
    SELECT gameAccountNo INTO v_gameAccountNo FROM accountAuth WHERE gameAccount = p_gameAccount;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_retcode := -17;
    v_retmsg := '秦寸 拌沥捞 粮犁窍瘤 臼嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) FROM  AccountLoginNotice WHERE gameAccountNo = v_gameAccountNo AND noticeEndDate > CURRENT_TIMESTAMP AND noticeTypeCode = p_noticeTypeCode) > 0 THEN
    v_retcode := -12;
    v_retmsg := '秦寸 拌沥捞 鞍篮 荤蜡肺 捞固 烹瘤 汲沥捞 登绢 乐嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    -- Transaction managed by PG function context
    INSERT INTO AccountLoginNotice ( gameAccountNo, noticeTypeCode, noticeStartDate, noticeEndDate) VALUES (v_gameAccountNo, p_noticeTypeCode, CURRENT_TIMESTAMP, p_noticeEndDate);
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    UPDATE AccountAuth  SET noticeFlag = ~(noticeFlag)    WHERE gameAccount = p_gameAccount;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    v_retcode := 1;
    v_retmsg := '秦寸 拌沥俊 措秦 烹瘤汲沥捞 捞固 登绢乐嚼聪促.';
    -- COMMIT (implicit in PG function)
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    -- Label: END_ROLLBACK
    RAISE NOTICE '%', @v_TRANCOUNT;
    IF @v_TRANCOUNT > 0 THEN
    RAISE NOTICE '%', 'didrollback';
    RAISE EXCEPTION 'Rollback requested';
    END IF;
    IF v_retcode IS NOT NULL THEN
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    END IF;
    RETURN NULL;
    -- Label: END_NO_ROLLBACK
    RAISE NOTICE '%', v_retcode;
    IF v_retcode IS NULL THEN
    v_retcode := -999;
    v_retmsg := '舅荐 绝绰 俊矾啊 惯积沁嚼聪促.';
    END IF;
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] aop_RemoveAccountNotice
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION aop_removeaccountnotice(
    p_gameAccount varchar(16),
    p_noticeTypeCode smallint
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_SysErrorCode integer;
    v_AffectedRowCnt integer;
    v_retcode integer;
    v_retmsg varchar(1024);
    v_gameAccountNo integer;
BEGIN
    SELECT gameAccountNo INTO v_gameAccountNo FROM accountAuth WHERE gameAccount = p_gameAccount;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_retcode := -17;
    v_retmsg := '秦寸 拌沥捞 粮犁窍瘤 臼嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) FROM  AccountLoginNotice WHERE gameAccountNo = v_gameAccountNo AND noticeEndDate > CURRENT_TIMESTAMP AND noticeTypeCode = p_noticeTypeCode) < 1 THEN
    v_retcode := -12;
    v_retmsg := '秦寸 拌沥篮 烹瘤 汲沥捞 登绢 乐瘤 臼嚼聪促.';
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN NULL;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    -- Transaction managed by PG function context
    UPDATE AccounLoginNotice SET noticeEndDate = CURRENT_TIMESTAMP WHERE gameAccountNo = v_gameAccountNo AND noticeTypeCode = p_noticeTypeCode;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) FROM  AccountLoginNotice WHERE gameAccountNo = v_gameAccountNo AND noticeEndDate > CURRENT_TIMESTAMP) > 0 THEN
    UPDATE AccountAuth  SET noticeFlag = 0 WHERE gameAccount = p_gameAccount;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN NULL;  -- Originally: GOTO END_ROLLBACK
    END IF;
    END IF;
    -- COMMIT (implicit in PG function)
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    -- Label: END_ROLLBACK
    RAISE NOTICE '%', @v_TRANCOUNT;
    IF @v_TRANCOUNT > 0 THEN
    RAISE NOTICE '%', 'didrollback';
    RAISE EXCEPTION 'Rollback requested';
    END IF;
    IF v_retcode IS NOT NULL THEN
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    END IF;
    RETURN NULL;
    -- Label: END_NO_ROLLBACK
    RAISE NOTICE '%', v_retcode;
    IF v_retcode IS NULL THEN
    v_retcode := -999;
    v_retmsg := '舅荐 绝绰 俊矾啊 惯积沁嚼聪促.';
    END IF;
    PERFORM v_retcode AS retcode, v_retmsg AS retmsg;
    RETURN NULL;
    RETURN 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_AutoReg

CREATE OR REPLACE FUNCTION ap_autoreg(
    p_account varchar(14)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_ssn char(13);
BEGIN
    v_ssn := (select  COALESCE(max(gameAccountNo),0) from AccountAuth) + 1;
    INSERT INTO AccountAuth (gameAccountNo, gameAccount, password, cryptographTypeCode, legalBirthday, genderCode, authLimitTypeBitSet) VALUES (v_ssn, p_account, CAST(0 AS bytea), 3, 0, 0, 1);
    INSERT INTO AccountETC (gameAccountNo, banServerBitSet, accountCreateDate) VALUES (v_ssn, binary(0), '1999-01-01');
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_DeleteAccountGameCharacter

CREATE OR REPLACE FUNCTION ap_deleteaccountgamecharacter(
    p_gameAccountNo integer,
    p_gameServerNo smallint,
    p_characterId integer,
    OUT p_result integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    v_rowCount := 0;
    DELETE FROM AccountGameCharacter WHERE gameAccountNo = p_gameAccountNo AND gameServerNo = p_gameServerNo AND characterNo = p_characterId;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_rowCount := v_rowcount;
    IF v_rowCount = 0 THEN
    p_result := 1;
    ELSE
    p_result := 0;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetAccountGameCharacter

CREATE OR REPLACE FUNCTION ap_getaccountgamecharacter(
    p_gameAccountNo integer,
    p_gameServerNo smallint,
    OUT p_characterId integer,
    OUT p_characterLevel integer,
    OUT p_result integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    v_rowCount := 0;
    SELECT characterNo, characterLevel INTO p_characterId, p_characterLevel FROM AccountGameCharacter WHERE gameAccountNo = p_gameAccountNo AND gameServerNo = p_gameServerNo;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_rowCount := v_rowcount;
    IF v_rowCount = 1 THEN
    p_result := 0;
    ELSE
    p_result := 1;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetAccountGameSlot

CREATE OR REPLACE FUNCTION ap_getaccountgameslot(
    p_gameAccountNo integer,
    OUT p_lastLogout timestamp,
    OUT p_slotStartTime timestamp,
    OUT p_slotCustomizeBitset bytea
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT AE.lastLogoutDate, AGS.gameSlotAvailStartDate, AGS.gameSlotCustomizeBitSet INTO p_lastLogout, p_slotStartTime, p_slotCustomizeBitset FROM AccountETC AS AE LEFT OUTER JOIN AccountGameSlot AS AGS ON AE.gameAccountNo = AGS.gameAccountNo WHERE AE.gameAccountNo = p_gameAccountNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetAccountMaxLevelCharacter

CREATE OR REPLACE FUNCTION ap_getaccountmaxlevelcharacter(
    p_gameAccountNo integer,
    OUT p_gameServerNo smallint,
    OUT p_characterId integer,
    OUT p_characterLevel integer,
    OUT p_result integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    v_rowCount := 0;
    SELECT gameServerNo, characterNo, characterLevel INTO p_gameServerNo, p_characterId, p_characterLevel FROM AccountGameCharacter WHERE gameAccountNo = p_gameAccountNo ORDER BY characterLevel DESC LIMIT 1;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_rowCount := v_rowcount;
    IF v_rowCount = 1 THEN
    p_result := 0;
    ELSE
    p_result := 1;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetGameAccountNo

CREATE OR REPLACE FUNCTION ap_getgameaccountno(
    p_gameAccount varchar(16)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	gameAccountNo FROM	AccountAuth WHERE	gameAccount = p_gameAccount;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetPcRegisterUseFlag

CREATE OR REPLACE FUNCTION ap_getpcregisteruseflag(
    p_gameAccountNo integer,
    OUT p_pcRegisterUseFlag integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    p_pcRegisterUseFlag := 0;
    SELECT COALESCE(fn_ap_GetPcRegisterFlag (gameAccountNo),0) INTO p_pcRegisterUseFlag FROM AccountAuth WHERE	gameAccountNo = p_gameAccountNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetRestriction

CREATE OR REPLACE FUNCTION ap_getrestriction(
    p_gameAccountNo integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	gameRestrictionReasonCode, CAST(restrictionEndDate AS char(8)) FROM	Restriction WHERE	gameAccountNo = p_gameAccountNo AND		restrictionStartDate <= CURRENT_TIMESTAMP AND		restrictionEndDate	>= CURRENT_TIMESTAMP;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetServers

CREATE OR REPLACE FUNCTION ap_getservers(
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	gameServerNo, gameServerName, publicNetworkIPAddress, privateNetworkIPAddress, userAgeLimit, fn_ap_GetPkFlag (COALESCE(serverCustomizeBitSet, 0)), fn_ap_GetKind (gameServerTypeCode, COALESCE(serverCustomizeBitSet, 0)), portNo, serverAreaCode FROM	GameServer ORDER BY gameServerNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GetSSN

CREATE OR REPLACE FUNCTION ap_getssn(
    p_gameAccountNo integer,
    OUT p_ssn char(13)
) RETURNS char(13)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT fn_ap_GetSSN (legalBirthday, genderCode) INTO p_ssn FROM AccountAuth WHERE	gameAccountNo = gameAccountNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GFatigueLastLogoutTime

CREATE OR REPLACE FUNCTION ap_gfatiguelastlogouttime(
    p_fcid integer,
    OUT p_SecFromLastLogout integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_lastLogout timestamp;
BEGIN
    SELECT COALESCE(lastLogoutDate, '2000-01-01') INTO v_lastLogout FROM Fatigue  WHERE	fcid = p_fcid;
    p_SecFromLastLogout := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (v_lastLogout)::timestamp)::integer;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GPwdWithFlag

CREATE OR REPLACE FUNCTION ap_gpwdwithflag(
    p_account varchar(16),
    OUT p_pwd bytea,
    OUT p_flag smallint
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    if(not exists(select gameAccount from AccountAuth where gameAccount=p_account)) begin;
    if(p_account not like '%^a-zA-Z0-9%') begin;
    p_pwd := 0;
    p_flag := 3;
    PERFORM ap_AutoReg(p_account);
    ELSE
    SELECT password, cryptographTypeCode INTO p_pwd, p_flag FROM AccountAuth WHERE	gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GStat

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
    SELECT AA.gameAccountNo, 0, fn_ap_GetLoginFlag (AA.gameAccountNo, noticeFlag, authLimitTypeBitSet, gameAccountGradeCode, CURRENT_TIMESTAMP), fn_ap_GetWarnFlag (AA.gameAccountNo, noticeFlag, CURRENT_TIMESTAMP), fn_ap_GetBlockFlag (AA.gameAccountNo, accountStatusCode), fn_ap_GetBlockFlag2 (AA.gameAccountNo, restrictFlag, CURRENT_TIMESTAMP), 0, AE.lastLoginGameServerNo, NULL, AE.banServerBitSet INTO p_uid, p_payStat, p_loginFlag, p_warnFlag, p_blockFlag, p_blockFlag2, p_subFlag, p_lastworld, p_block_end_date, p_forbidden_servers FROM AccountAuth AA INNER JOIN AccountETC AE ON (AA.gameAccountNo = AE.gameAccountNo) WHERE	gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GStatEtc

CREATE OR REPLACE FUNCTION ap_gstatetc(
    p_account varchar(14)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT accountCustomizeBitSet , COALESCE(datalength (accountCustomizeBitSet), 0) FROM	AccountAuth AA INNER JOIN AccountEtc AE  ON (AA.gameAccountNo = AE.gameAccountNo) WHERE	gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_GStatEtcT

CREATE OR REPLACE FUNCTION ap_gstatetct(
    p_account varchar(14)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	fn_ap_GetSSN (AA.legalBirthday, AA.genderCode) , fn_ap_GetAge (AA.legalBirthDay, CURRENT_TIMESTAMP) , fn_ap_GetFatigueAuthFlag (AA.gameAccountNo) , fn_ap_GetFatigueId (AA.gameAccountNo) , accountCustomizeBitSet , COALESCE(datalength (accountCustomizeBitSet), 0) , COALESCE(packageVersionInfo, 0) FROM	AccountAuth AA  INNER JOIN AccountEtc AE  ON (AA.gameAccountNo = AE.gameAccountNo) WHERE	AA.gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_ModifyOtpFlag

CREATE OR REPLACE FUNCTION ap_modifyotpflag(
    p_account varchar(16),
    OUT p_ErrorCode integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
BEGIN
    p_ErrorCode := 0;
    UPDATE AccountSecurityService SET accountSecurityStatusCode = 1 FROM AccountAuth AA INNER JOIN AccountSecurityService ASS ON AA.gameAccountNo = ASS.gameAccountNo WHERE AA.gameAccount = p_account AND ASS.accountSecurityMethodCode = 1;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount  = 0 THEN
    p_ErrorCode := 1;
    END IF;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] ap_RegisterAccountGameCharacter
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

CREATE OR REPLACE FUNCTION ap_registeraccountgamecharacter(
    p_gameAccountNo integer,
    p_gameServerNo smallint,
    p_characterId integer,
    p_characterLevel integer,
    p_modifyDate timestamp,
    p_forceRegister boolean,
    OUT p_result integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount integer := 0;
    v_currentLevel integer;
BEGIN
    v_currentLevel := 0;
    v_rowCount := 0;
    -- Transaction managed by PG function context
    BEGIN
    SELECT characterLevel INTO v_currentLevel FROM AccountGameCharacter where gameAccountNo = p_gameAccountNo and gameServerNo = p_gameServerNo;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    v_rowCount := v_rowcount;
    IF v_rowCount = 0 THEN
    INSERT INTO AccountGameCharacter(gameAccountNo, gameServerNo, characterNo, characterLevel, modifyDate) values(p_gameAccountNo, p_gameServerNo, p_characterId, p_characterLevel, p_modifyDate);
    ELSIF p_characterLevel > v_currentLevel OR p_forceRegister = 1 THEN
    UPDATE AccountGameCharacter SET characterNo = p_characterId, characterLevel = p_characterLevel, modifyDate = p_modifyDate WHERE gameAccountNo = p_gameAccountNo and gameServerNo = p_gameServerNo;
    END IF;
    EXCEPTION WHEN OTHERS THEN
    p_result := 1;
    RAISE EXCEPTION 'Rollback requested';
    RETURN;
    END;
    -- COMMIT (implicit in PG function)
    p_result := 0;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_RegisterAccountGameSlot

CREATE OR REPLACE FUNCTION ap_registeraccountgameslot(
    p_gameAccountNo integer,
    p_slotStartTime timestamp,
    p_slotCustomizeBitset bytea,
    OUT p_result integer
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowCount integer;
BEGIN
    v_rowCount := 0;
    SELECT COUNT(p_gameAccountNo) INTO v_rowCount FROM AccountGameSlot WHERE gameAccountNo = p_gameAccountNo;
    BEGIN
    IF v_rowCount = 0 THEN
    INSERT INTO AccountGameSlot(gameAccountNo, gameSlotAvailStartDate, gameSlotCustomizeBitSet) VALUES(p_gameAccountNo, p_slotStartTime, p_slotCustomizeBitset);
    ELSE
    UPDATE AccountGameSlot SET gameSlotAvailStartDate = p_slotStartTime, gameSlotCustomizeBitSet = p_slotCustomizeBitset WHERE gameAccountNo = p_gameAccountNo;
    END IF;
    EXCEPTION WHEN OTHERS THEN
    p_result := 1;
    RETURN;
    END;
    p_result := 0;
END;
$$;

-- --------------------------------------------------------

-- [WARN] [REVIEW] ap_SetAccountRestirction
--   Warning: GOTO statements detected - converted to RETURN where possible
--   Warning: ROLLBACK TRANSACTION converted to RAISE EXCEPTION

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
    v_restrictionCode := 43;
    v_restrictionCode := CASE p_restrictionReasonCode WHEN 0 THEN 43;
    ELSE 43;
    SELECT gameAccount INTO p_gameAccount FROM accountAuth WHERE gameAccountNo = p_gameAccountNo;
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    IF v_rowcount = 0 THEN
    v_retcode := 1;
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    IF (SELECT COUNT(*) FROM   Restriction WHERE gameAccountNo = p_gameAccountNo AND restrictionEndDate > CURRENT_TIMESTAMP AND gameRestrictionReasonCode = v_restrictionCode) > 0 THEN
    v_retcode := 2;
    -- TODO: MANUAL REVIEW NEEDED - GOTO END_NO_ROLLBACK
    RETURN;  -- Originally: GOTO END_NO_ROLLBACK
    END IF;
    -- Transaction managed by PG function context
    INSERT INTO Restriction ( gameAccountNo, gameRestrictionReasonCode, restrictionStartDate, restrictionEndDate, restrictionExpireDate) VALUES ( p_gameAccountNo, v_restrictionCode, CURRENT_TIMESTAMP, v_restrictionEndDate, v_restrictionEndDate);
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN;  -- Originally: GOTO END_ROLLBACK
    END IF;
    p_restrictionNo := LASTVAL();
    UPDATE AccountAuth SET  restrictFlag = 1 where gameAccountNo = p_gameAccountNo;
    IF 0 /* @v_ERROR */ <> 0 THEN
        RETURN;  -- Originally: GOTO END_ROLLBACK
    END IF;
    -- COMMIT (implicit in PG function)
    p_return_code := 0;
        -- RETURN_EXPR: v_retcode;
    -- Label: END_ROLLBACK
    IF @v_TRANCOUNT > 0 THEN
    RAISE EXCEPTION 'Rollback requested';
    END IF;
    v_retcode := 3;
    p_return_code := 0;
        -- RETURN_EXPR: v_retcode;
    -- Label: END_NO_ROLLBACK
    IF v_retcode IS NULL THEN
    v_retcode := 999;
    END IF;
    p_return_code := 0;
        -- RETURN_EXPR: v_retcode;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SetConcurrentUserStatistics

CREATE OR REPLACE FUNCTION ap_setconcurrentuserstatistics(
    p_serverNo smallint,
    p_concurrentWorldUserCount integer,
    p_concurrentUserLimit integer,
    p_concurrentAuthUserCount integer,
    p_concurrentAuthWaitCount integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_serverNo = 0 THEN
    INSERT INTO	ConcurrentUserStat (serverNo, serverTypeCode, concurrentUserStatTypeCode, concurrentUserLimit, concurrentUserCount, registerDate) VALUES (p_serverNo, 1, 2, p_concurrentUserLimit, p_concurrentAuthUserCount, CURRENT_TIMESTAMP);
    INSERT INTO	ConcurrentUserStat (serverNo, serverTypeCode, concurrentUserStatTypeCode, concurrentUserLimit, concurrentUserCount, registerDate) VALUES (p_serverNo, 1, 1, p_concurrentUserLimit, p_concurrentAuthWaitCount, CURRENT_TIMESTAMP);
    ELSE
    INSERT INTO	ConcurrentUserStat (serverNo, serverTypeCode, concurrentUserStatTypeCode, concurrentUserLimit, concurrentUserCount, registerDate) VALUES (p_serverNo, 2, 2, p_concurrentUserLimit, p_concurrentWorldUserCount, CURRENT_TIMESTAMP);
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SetIllegalLoginTrace

CREATE OR REPLACE FUNCTION ap_setillegallogintrace(
    p_gameAccountNo integer,
    p_IP varchar(15),
    p_traceTypeCode smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO	IllegalLoginTrace (gameAccountNo, illegalLoginTraceTypeCode, IPAddress, registerDate) VALUES (p_gameAccountNo, p_traceTypeCode, p_IP, CURRENT_TIMESTAMP);
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SetPasswordResetFlag

CREATE OR REPLACE FUNCTION ap_setpasswordresetflag(
    p_gameAccountNo integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO AccountLoginNotice VALUES	(p_gameAccountNo, 3, CURRENT_TIMESTAMP, '9999-12-31');
    UPDATE	AccountAuth SET		noticeFlag = 1 WHERE	gameAccountNo = p_gameAccountNo;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SetServerStatus

CREATE OR REPLACE FUNCTION ap_setserverstatus(
    p_gameServerNo smallint,
    p_statusCode smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_gameServerNo = 0 THEN
    UPDATE	GameServer SET		gameServerStatusCode = p_statusCode;
    ELSE
    UPDATE	GameServer SET		gameServerStatusCode = p_statusCode;
    END IF;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SetServerStatusT

CREATE OR REPLACE FUNCTION ap_setserverstatust(
    p_gameServerNo smallint,
    p_statusCode smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_gameServerNo = 0 THEN
    UPDATE GameServer SET  gameServerStatusCode = p_statusCode;
    ELSE
    UPDATE GameServer SET  gameServerStatusCode = p_statusCode WHERE gameServerNo = p_gameServerNo;
    END IF;
    RETURN;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SFatiguePlayTime

CREATE OR REPLACE FUNCTION ap_sfatigueplaytime(
    p_fcid integer,
    p_playTime integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	Fatigue SET	playTime = playTime + p_playTime, lastLogoutDate = CURRENT_TIMESTAMP WHERE	fcid = p_fcid;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SFatigueRestTime

CREATE OR REPLACE FUNCTION ap_sfatigueresttime(
    p_fcid integer,
    p_concurrentCnt integer,
    p_refreshTime integer,
    OUT p_playTime integer,
    OUT p_restTime integer
) RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_logout timestamp;
BEGIN
    SELECT COALESCE(lastLogoutDate, '2000-01-01'), restTime, p_playTime + playTime INTO v_last_logout, p_restTime, p_playTime FROM Fatigue  WHERE 	fcid = p_fcid;
    IF (p_concurrentCnt = 1) THEN
    p_restTime := p_restTime + EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP)::timestamp - (v_last_logout)::timestamp)::integer;
    IF (p_restTime > p_refreshTime) THEN
    p_restTime := 0;
    p_playTime := 0;
    UPDATE	Fatigue SET		playTime = p_playTime, restTime = p_restTime WHERE	fcid = p_fcid;
    ELSE
    UPDATE	Fatigue SET		restTime = p_restTime WHERE	fcid = p_fcid;
    END IF;
    END IF;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SLog

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
    UPDATE AccountETC SET lastLoginDate = p_lastlogin, lastLogoutDate = p_lastlogout, lastLoginGameServerNo = p_LastWorld WHERE	gameAccountNo = p_uid;
    SELECT hardware INTO v_hardware WHERE gameAccountNo = p_uid;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SNewPwd

CREATE OR REPLACE FUNCTION ap_snewpwd(
    p_account varchar(14),
    p_pwd bytea,
    p_encFlag smallint
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	AccountAuth SET		cryptographTypeCode = p_encFlag, password = p_pwd WHERE	gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

-- [OK] [AUTO] ap_SUserData

CREATE OR REPLACE FUNCTION ap_suserdata(
    p_account varchar(14),
    p_userdata_size smallint,
    p_userdata bytea
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	AE SET		accountCustomizeBitSet = p_userdata FROM	AccountAuth AA INNER JOIN AccountETC AE ON (AA.gameAccountNo = AE.gameAccountNo) WHERE	AA.gameAccount = p_account;
END;
$$;

-- --------------------------------------------------------

