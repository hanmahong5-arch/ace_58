-- AionCore 5.8 — Sprint 1.1a batch 2 port: aion_AddBuddy + buddy table scaffold.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddBuddy.sql
-- Original (T-SQL):
--   IF NOT EXISTS(SELECT char_id FROM user_buddy1(updlock)
--                  WHERE char_id = @nCharId AND buddy_id = @nBuddyId)
--   BEGIN
--     INSERT user_buddy1 (char_id, buddy_id, delete_flag) VALUES (@nCharId, @nBuddyId, 0)
--   END
--
-- Translation notes:
--   * NCSoft table name is `user_buddy1` (numeric suffix dates from the early
--     2007-era partition layout). PG side uses the more readable `user_buddy_list`
--     per the AionCore convention; semantically identical.
--   * `(updlock)` hint becomes a PG advisory lock equivalent: we use
--     ON CONFLICT DO NOTHING which serialises through the unique index so
--     two concurrent INSERTs collapse into a single row without a phantom-read
--     race.
--   * `delete_flag` is preserved verbatim because subsequent ports
--     (aion_RemoveBuddy / aion_GetBuddyList variants) flip it to 1 instead of
--     row-deleting; the column drives a soft-delete protocol identical to
--     user_mail / user_familiar.
--
-- Returns the number of rows actually inserted (0 = duplicate, 1 = new).
-- Caller (scripts/lib/buddy.lua, future) uses this to decide whether to push
-- SM_FRIEND_LIST update events to the new buddy.

-- +goose Up
-- +goose StatementBegin
-- The buddy list lives across both directions: (A → B) and (B → A) are stored
-- as two rows so that one-way add (block / pending invite) is representable
-- and aion_GetBuddyIdList(charId) trivially returns the outbound list.
CREATE TABLE IF NOT EXISTS user_buddy_list (
    char_id      INTEGER NOT NULL,
    buddy_id     INTEGER NOT NULL,
    delete_flag  SMALLINT NOT NULL DEFAULT 0,
    create_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (char_id, buddy_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_buddy_list_buddy ON user_buddy_list(buddy_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addbuddy(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addbuddy(
    _char_id  INTEGER,
    _buddy_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    inserted_cnt INTEGER;
BEGIN
    INSERT INTO user_buddy_list (char_id, buddy_id, delete_flag)
    VALUES (_char_id, _buddy_id, 0)
    ON CONFLICT (char_id, buddy_id) DO NOTHING;
    GET DIAGNOSTICS inserted_cnt = ROW_COUNT;
    RETURN inserted_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addbuddy(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_buddy_list_buddy;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_buddy_list;
-- +goose StatementEnd
