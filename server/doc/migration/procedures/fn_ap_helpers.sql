-- Real implementations of fn_ap_* helper functions
-- Converted from NCSoft SQL Server UDFs (extracted 2026-04-12)
-- Source: 123.56.80.174 AionAccountDB

-- fn_ap_GetPkFlag: Check PK server flag from customize bitset
CREATE OR REPLACE FUNCTION fn_ap_getpkflag(p_customize_attribute integer)
RETURNS smallint LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF p_customize_attribute & 1 = 1 THEN
        RETURN 1;
    END IF;
    RETURN 0;
END;
$$;

-- fn_ap_GetBlockFlag: Check if account is blocked (status 3=banned, 4=suspended)
CREATE OR REPLACE FUNCTION fn_ap_getblockflag(
    p_game_account_no integer,
    p_account_status_code integer
) RETURNS integer LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF p_account_status_code IN (3, 4) THEN
        RETURN 1;
    END IF;
    RETURN 0;
END;
$$;

-- fn_ap_GetBlockFlag2: Check time-based restrictions
CREATE OR REPLACE FUNCTION fn_ap_getblockflag2(
    p_game_account_no integer,
    p_restrict_flag integer,
    p_today timestamp
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
    v_flag integer := 0;
    v_restrict_count integer;
BEGIN
    IF p_restrict_flag IS NOT NULL AND p_restrict_flag != 0 THEN
        SELECT COUNT(*) INTO v_restrict_count
        FROM restriction
        WHERE gameaccountno = p_game_account_no
          AND restricttypecode IN (1, 2, 3, 4, 5)
          AND restrictstartdate <= p_today
          AND restrictenddate >= p_today;
        IF v_restrict_count > 0 THEN
            v_flag := 1;
        END IF;
    END IF;
    RETURN v_flag;
END;
$$;

-- fn_ap_GetLoginFlag: Compute login state flags (notices, auth limits, grade)
CREATE OR REPLACE FUNCTION fn_ap_getloginflag(
    p_game_account_no integer,
    p_notice_flag integer,
    p_auth_limit_type_bitset integer,
    p_game_account_grade_code smallint,
    p_today timestamp
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
    v_login_flag integer := 0;
    v_notice_sum integer;
BEGIN
    -- Check login notices
    IF p_notice_flag = 1 THEN
        SELECT COALESCE(SUM(DISTINCT
            CASE noticetypecode
                WHEN 3 THEN 1
                WHEN 4 THEN 2
            END), 0) INTO v_notice_sum
        FROM accountloginnotice
        WHERE gameaccountno = p_game_account_no
          AND noticestartdate <= p_today
          AND noticeenddate >= p_today;
        v_login_flag := v_notice_sum;
    END IF;

    -- Auth limit checks
    IF p_auth_limit_type_bitset = 0 THEN
        v_login_flag := v_login_flag | 32;
    END IF;

    IF p_auth_limit_type_bitset & 2 = 2 THEN
        v_login_flag := v_login_flag | 16;
    END IF;

    -- Grade checks
    IF p_game_account_grade_code = 2 THEN
        v_login_flag := v_login_flag | 256;
    END IF;
    IF p_game_account_grade_code = 3 THEN
        v_login_flag := v_login_flag | 1024;
    END IF;

    RETURN v_login_flag;
END;
$$;

-- fn_ap_GetWarnFlag: Check warning notifications
CREATE OR REPLACE FUNCTION fn_ap_getwarnflag(
    p_game_account_no integer,
    p_notice_flag integer,
    p_today timestamp
) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
    v_warn_flag integer := 0;
    v_notice_count integer;
BEGIN
    IF p_notice_flag = 1 THEN
        SELECT COUNT(*) INTO v_notice_count
        FROM accountloginnotice
        WHERE gameaccountno = p_game_account_no
          AND noticetypecode = 1
          AND noticestartdate <= p_today
          AND noticeenddate >= p_today;
        IF v_notice_count > 0 THEN
            v_warn_flag := 1;
        END IF;
    END IF;
    RETURN v_warn_flag;
END;
$$;

-- fn_ap_GetKind: Determine server kind from type code + customize bitset
CREATE OR REPLACE FUNCTION fn_ap_getkind(
    p_type_code smallint,
    p_customize_bitset integer
) RETURNS smallint LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_kind smallint := 0;
BEGIN
    -- Bit 1: PK server
    IF p_customize_bitset & 1 = 1 THEN
        v_kind := v_kind | 1;
    END IF;
    -- Bit 2: Free-to-play server
    IF p_customize_bitset & 2 = 2 THEN
        v_kind := v_kind | 2;
    END IF;
    -- Type 1 = test server
    IF p_type_code = 1 THEN
        v_kind := v_kind | 4;
    END IF;
    RETURN v_kind;
END;
$$;

-- fn_ap_GetAge: Calculate age from birthday (YYYYMMDD integer)
CREATE OR REPLACE FUNCTION fn_ap_getage(p_birthday integer)
RETURNS integer LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_year integer;
    v_now_year integer;
BEGIN
    IF p_birthday IS NULL OR p_birthday = 0 THEN
        RETURN 99;
    END IF;
    v_year := p_birthday / 10000;
    v_now_year := EXTRACT(YEAR FROM CURRENT_DATE)::integer;
    RETURN v_now_year - v_year;
END;
$$;

-- fn_ap_GetOtpFlag: OTP status (always 0 when OTP disabled)
CREATE OR REPLACE FUNCTION fn_ap_getotpflag(p_game_account_no integer)
RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
    SELECT 0::smallint;
$$;

-- fn_ap_GetTasFlag: TAS status (always 0 when TAS disabled)
CREATE OR REPLACE FUNCTION fn_ap_gettasflag(p_game_account_no integer)
RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
    SELECT 0::smallint;
$$;

-- fn_ap_GetPcRegisterFlag: PC registration (always 0 for private server)
CREATE OR REPLACE FUNCTION fn_ap_getpcregisterflag(p_game_account_no integer, p_flag integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
    SELECT 0;
$$;

-- fn_ap_GetSecurityCard: Security card status (always 0 when disabled)
CREATE OR REPLACE FUNCTION fn_ap_getsecuritycard(p_game_account_no integer)
RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
    SELECT 0::smallint;
$$;

-- fn_ap_GetServiceFlag: Service status flags
CREATE OR REPLACE FUNCTION fn_ap_getserviceflag(p_game_account_no integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
    SELECT 0;
$$;

-- fn_ap_GetFatigueAuthFlag: Fatigue system auth (always 0 when disabled)
CREATE OR REPLACE FUNCTION fn_ap_getfatigueauthflag(p_game_account_no integer)
RETURNS smallint LANGUAGE sql IMMUTABLE AS $$
    SELECT 0::smallint;
$$;

-- fn_ap_GetFatigueId: Fatigue ID (always 0 when disabled)
CREATE OR REPLACE FUNCTION fn_ap_getfatigueid(p_game_account_no integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
    SELECT 0;
$$;

-- fn_ap_GetSSN: Get SSN/identifier (always empty for private server)
CREATE OR REPLACE FUNCTION fn_ap_getssn(p_game_account_no integer)
RETURNS varchar LANGUAGE sql IMMUTABLE AS $$
    SELECT ''::varchar;
$$;

-- GetUnixtimeWithUTCAdjust: Convert timestamp to Unix epoch (SQL Server UDF replacement)
-- Used by 50+ stored procedures across aion_account_cache_db and aion_world_live
CREATE OR REPLACE FUNCTION getunixtimewithutcadjust(p_time timestamp, p_offset integer DEFAULT 0)
RETURNS bigint LANGUAGE sql IMMUTABLE AS $$
    SELECT (EXTRACT(EPOCH FROM p_time) + p_offset)::bigint;
$$;
