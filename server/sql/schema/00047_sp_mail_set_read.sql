-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_MailSetRead.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailSetRead.sql
-- Marks one mail as read without returning its body.
-- Returns 0 on success, 1 on "no row matched" (invalid id or already read).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailsetread(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailsetread(_char_id INTEGER, _mail_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    -- Use table alias to avoid potential ambiguity with future RETURNS TABLE
    -- column-name additions.
    UPDATE user_mail um
       SET state = 1
     WHERE um.id = _mail_id AND um.to_id = _char_id AND um.state = 0;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RETURN 1;
    END IF;
    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailsetread(INTEGER, BIGINT);
-- +goose StatementEnd
