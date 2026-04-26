-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_MailDelete.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailDelete.sql
-- Deletes one mail row and (cascading) the attached item. Returns
-- (rc, state) where rc=0 means success, rc=1 means mail not found.
-- The previous "state" is returned so the caller can update unread counters.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maildelete(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_maildelete(_char_id INTEGER, _mail_id BIGINT)
RETURNS TABLE (rc INTEGER, prev_state SMALLINT)
LANGUAGE plpgsql AS $$
DECLARE
    v_item_id   BIGINT;
    v_state     SMALLINT := 0;
    v_found     BOOLEAN  := FALSE;
BEGIN
    SELECT um.item_id, um.state INTO v_item_id, v_state
      FROM user_mail um
     WHERE um.id = _mail_id AND um.to_id = _char_id;

    IF NOT FOUND THEN
        -- T-SQL returns (1, @state=0) when no match.
        RETURN QUERY SELECT 1, 0::SMALLINT;
        RETURN;
    END IF;

    v_found := TRUE;

    -- Cascade delete the attachment via the existing aion_DeleteItem SP.
    IF v_item_id IS NOT NULL AND v_item_id <> 0 THEN
        PERFORM aion_deleteitem(v_item_id);
    END IF;

    DELETE FROM user_mail um WHERE um.id = _mail_id AND um.to_id = _char_id;

    RETURN QUERY SELECT 0, v_state;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maildelete(INTEGER, BIGINT);
-- +goose StatementEnd
