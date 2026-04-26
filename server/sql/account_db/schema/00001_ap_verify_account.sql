-- AionCore 5.8 — Account DB SP port #1: ap_verify_account.
--
-- Target database: aion_account_db (separate from aion_world_live).
-- Apply manually:
--   psql -h 127.0.0.1 -U postgres -d aion_account_db -f 00001_ap_verify_account.sql
--
-- This is the gateway's auth gate (server/src/cmd/gateway/main.go:318):
--   db.CallSPRow(ctx, "ap_verify_account", account, password).Scan(&accountID)
--
-- The Go layer expects:
--   - SETOF BIGINT return: 1 row (account_id) on success, 0 rows on failure
--   - 0-row result surfaces as pgx.ErrNoRows → gateway sends SM_LOGIN_FAIL
--
-- The accountauth table is the NCSoft-imported AccountAuth (lower-cased by the
-- import), already present in aion_account_db. Existing test rows have empty
-- password (length 0); we treat that as "dev-mode pass-through" so dev/test
-- accounts authenticate without needing a hashed password column.
--
-- Password storage: NCSoft used MD5(password) → 16-byte BINARY. We mirror that
-- (BYTEA column). Real production will require a one-time migration to bcrypt
-- once we accept account-creation via UI; for Sprint 0/Q1 the MD5 path keeps
-- bit-compatibility with the imported test corpus.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS ap_verify_account(TEXT, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION ap_verify_account(
    p_account  TEXT,
    p_password TEXT
) RETURNS SETOF BIGINT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    r_id      INTEGER;
    r_pwhash  BYTEA;
    r_status  SMALLINT;
    r_banned  BOOLEAN;
BEGIN
    -- Single fetch covers existence + status + password retrieval.
    SELECT gameaccountno, password, accountstatuscode, restrictflag
      INTO r_id, r_pwhash, r_status, r_banned
      FROM accountauth
     WHERE gameaccount = p_account
     LIMIT 1;

    IF NOT FOUND THEN
        RETURN;  -- 0 rows = unknown account
    END IF;

    -- Banned or non-active account.
    IF r_banned OR r_status <> 1 THEN
        RETURN;
    END IF;

    -- Dev / test accounts have empty password column → accept any password.
    -- Production accounts store md5(password) as 16 raw bytes.
    IF r_pwhash IS NULL OR octet_length(r_pwhash) = 0 THEN
        RETURN NEXT r_id::BIGINT;
        RETURN;
    END IF;

    -- md5(text) returns 32-char hex; decode to 16 raw bytes for byte compare.
    IF r_pwhash = decode(md5(p_password), 'hex') THEN
        RETURN NEXT r_id::BIGINT;
    END IF;

    -- Mismatch → 0 rows returned.
    RETURN;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS ap_verify_account(TEXT, TEXT);
-- +goose StatementEnd
