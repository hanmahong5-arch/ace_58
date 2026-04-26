-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_CheckValidCharName.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_CheckValidCharName.sql
-- Returns:
--   0  — name is valid
--  -1  — name already taken by an alive char
--  -2  — name matches forbidden_word (full or LIKE-substring)
--  -3  — name is reserved by another account (forbidden_char.reason=2)
--
-- Auto-port pass: 50%. T-SQL had nested IF-EXISTS chains; in plpgsql we use
-- early RETURN for clarity. The 366-day vs 61-day cutoff for forbidden_char
-- (server-transfer / item-rename name reservations) is preserved exactly
-- against the 2016-07-06 boundary date documented in the original SP.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkvalidcharname(TEXT, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkvalidcharname(
    _name    TEXT,
    _account TEXT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    _apply_date TIMESTAMPTZ := '2016-07-06 09:00:00+00'::TIMESTAMPTZ;
    _now_epoch  BIGINT := GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0);
BEGIN
    -- 1. Name already in use by an alive (non-deleted) char
    IF EXISTS (
        SELECT 1 FROM user_data
         WHERE user_id = _name
           AND (delete_date = 0 OR delete_date > _now_epoch)
    ) THEN
        RETURN -1;
    END IF;

    -- 2. Forbidden word — exact match (IS_LIKE=0), char or common bucket
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE forbidden_word = _name
           AND is_like = 0 AND status = 0
           AND forbidden_type IN (0, 1)
    ) THEN
        RETURN -2;
    END IF;

    -- 3. Forbidden word — substring match (IS_LIKE=1)
    IF EXISTS (
        SELECT 1 FROM forbidden_word
         WHERE _name LIKE '%' || forbidden_word || '%'
           AND forbidden_word <> ''
           AND is_like = 1 AND status = 0
           AND forbidden_type IN (0, 1)
    ) THEN
        RETURN -2;
    END IF;

    -- 4. Reserved by server-transfer (3) / item-rename (4): 366-day pre-cutoff,
    --    61-day post-cutoff (2016-07-06)
    IF EXISTS (
        SELECT 1 FROM forbidden_char
         WHERE forbidden_char = _name
           AND status = 0
           AND forbidden_reason IN (3, 4)
           AND ((regdate < _apply_date AND (NOW()::DATE - regdate::DATE) < 366)
                OR (NOW()::DATE - regdate::DATE) < 61)
    ) THEN
        RETURN -2;
    END IF;

    -- 5. Pre-reserved (forbidden_reason=2) — only the owning account may use it
    IF EXISTS (
        SELECT 1 FROM forbidden_char
         WHERE forbidden_char = _name AND status = 0 AND forbidden_reason = 2
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM forbidden_char
             WHERE forbidden_char = _name
               AND forbidden_account_nm = _account
               AND status = 0 AND forbidden_reason = 2
        ) THEN
            RETURN -3;
        END IF;
    END IF;

    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkvalidcharname(TEXT, TEXT);
-- +goose StatementEnd
