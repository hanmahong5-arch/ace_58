-- Fix ap_gpwdwithflag: correct PL/pgSQL conversion from T-SQL
-- Original logic:
--   IF account not exists:
--     IF account name is valid (alphanumeric only):
--       Set pwd=zeros, flag=3, call ap_autoreg
--   ELSE:
--     SELECT password, cryptographTypeCode from AccountAuth

DROP FUNCTION IF EXISTS ap_gpwdwithflag(varchar);

CREATE OR REPLACE FUNCTION ap_gpwdwithflag(
    p_account varchar(16),
    OUT p_pwd bytea,
    OUT p_flag smallint
) RETURNS record
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM accountauth WHERE gameaccount = p_account) THEN
        -- Account doesn't exist. Auto-register if name is valid (alphanumeric).
        IF p_account ~ '^[a-zA-Z0-9]+$' THEN
            p_pwd := E'\\x00000000000000000000000000000000'::bytea;
            p_flag := 3;
            PERFORM ap_autoreg(p_account);
        ELSE
            -- Invalid characters in account name — return empty
            p_pwd := NULL;
            p_flag := -1;
        END IF;
    ELSE
        -- Account exists — return password and crypto type
        SELECT password, cryptographtypecode
        INTO p_pwd, p_flag
        FROM accountauth
        WHERE gameaccount = p_account;
    END IF;
END;
$$;
