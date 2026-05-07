-- AionCore 5.8 — Sprint 1.1a batch 3 port: aion_BlockOfflineBuddy.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_BlockOfflineBuddy.sql
--
-- Original (T-SQL) — paraphrased:
--   if (charid, inviterId) ACTIVE row in user_buddy1 (delete_flag=0)        → return 4 (BKT_INVALID)
--   if (charid, inviterId) row in user_block already exists                 → return 0 (silently OK)
--   if charid's user_block count >= 200                                     → return 3 (block-list full)
--   else INSERT user_block (charid, inviterId, '')                          → return 0
--
-- Use case: a player receives an offline-buddy invite (queued by
-- aion_AddOfflineBuddy) and elects to BLOCK the inviter instead of accepting.
-- The "already friends" branch (BKT_INVALID/4) is the safety rail: blocking
-- someone you actively friend should require unfriending first; the client
-- normally guards this but the SP is the authoritative gate.
--
-- Translation notes:
--   * No schema delta — both user_buddy_list (00144) and user_block (00072)
--     already exist with the right columns.
--   * NCSoft used 200 as the block-list ceiling — same value as the active
--     buddy ceiling (aion_AnswerOfflineBuddy), unlike the asymmetric 100/200
--     pair we documented in 00151.
--   * The pre-existing user_block row case returns 0 (success) deliberately:
--     "block someone you've already blocked" is a no-op, not an error. We
--     mirror this exactly with ON CONFLICT DO NOTHING + an explicit RETURN 0.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_block_offline_buddy(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_block_offline_buddy(
    _char_id    INTEGER,
    _inviter_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    block_count INTEGER;
BEGIN
    -- (1) Active friendship safety rail — must unfriend first.
    IF EXISTS (SELECT 1 FROM user_buddy_list
                WHERE char_id  = _char_id
                  AND buddy_id = _inviter_id
                  AND delete_flag = 0) THEN
        RETURN 4;
    END IF;

    -- (2) Already blocked → silently succeed (idempotent).
    IF EXISTS (SELECT 1 FROM user_block
                WHERE char_id = _char_id
                  AND block_id = _inviter_id) THEN
        RETURN 0;
    END IF;

    -- (3) Block-list ceiling.
    SELECT COUNT(*) INTO block_count FROM user_block WHERE char_id = _char_id;
    IF block_count >= 200 THEN
        RETURN 3;
    END IF;

    -- (4) Add to block list with empty comment (NCSoft default).
    INSERT INTO user_block (char_id, block_id, comment)
    VALUES (_char_id, _inviter_id, '')
    ON CONFLICT (char_id, block_id) DO NOTHING;

    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_block_offline_buddy(INTEGER, INTEGER);
-- +goose StatementEnd
