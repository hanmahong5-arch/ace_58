-- Fix ap_autoreg: correct PL/pgSQL conversion
-- Original: generates sequential gameAccountNo, inserts into both AccountAuth and AccountETC

DROP FUNCTION IF EXISTS ap_autoreg(varchar);

CREATE OR REPLACE FUNCTION ap_autoreg(
    p_account varchar(14)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_account_no integer;
BEGIN
    -- Generate next account number (sequential, like NCSoft original)
    SELECT COALESCE(MAX(gameaccountno), 0) + 1 INTO v_account_no FROM accountauth;

    -- Insert main account record
    INSERT INTO accountauth (
        gameaccountno, gameaccount, password,
        cryptographtypecode, legalbirthday, gendercode, authlimittypebitset
    ) VALUES (
        v_account_no, p_account,
        E'\\x00000000000000000000000000000000'::bytea,
        3, 0, 0, 1
    );

    -- Insert extended account record (AccountETC)
    -- Only if the table exists (it should from NCSoft migration)
    BEGIN
        INSERT INTO accountetc (gameaccountno, banserverbitset, accountcreatedate)
        VALUES (v_account_no, E'\\x00000000000000000000000000000000'::bytea, '1999-01-01');
    EXCEPTION WHEN undefined_table THEN
        -- AccountETC table might not exist yet
        NULL;
    END;
END;
$$;
