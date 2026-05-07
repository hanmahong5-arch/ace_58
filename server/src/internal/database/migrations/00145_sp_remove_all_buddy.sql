-- AionCore 5.8 — Sprint 1.1a batch 2 port: aion_RemoveAllBuddy.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemoveAllBuddy.sql
-- Original (T-SQL):
--   DELETE FROM user_buddy1 WHERE buddy_id = @nCharId
--   (the @nCharId = @charId branch is commented out in the NCSoft source —
--    only the inbound direction is purged on char-delete because the outbound
--    rows stay valid until the OWNER deletes their char and triggers their
--    own cascade)
--
-- Translation notes:
--   * Delete predicate is `buddy_id = @nCharId`, NOT `char_id = @nCharId`.
--     This is the inbound side — when char X is deleted, we strip X from all
--     OTHER chars' friend lists so they don't see a ghost in their UI.
--     The outbound rows (X's own friend list) are removed by the cascade in
--     aion_DeleteCharByCharId — but only when the char is ACTUALLY deleted,
--     which is currently driven by the user_data trigger.
--   * NCSoft purges hard (DELETE), not soft (delete_flag=1). We mirror this:
--     once a char is gone, leaving stale rows in friends' lists would corrupt
--     SM_FRIEND_LIST snapshots downstream.
--
-- Used by: scripts/handlers/cm_delete_character.lua (future) — invoked after
-- the soft-delete grace expires and the char row is being scrubbed.
--
-- Returns the number of rows deleted (helpful for a debug/info log; the call
-- is fire-and-forget from the cascade path).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeallbuddy(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeallbuddy(_char_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    deleted_cnt INTEGER;
BEGIN
    DELETE FROM user_buddy_list
     WHERE buddy_id = _char_id;
    GET DIAGNOSTICS deleted_cnt = ROW_COUNT;
    RETURN deleted_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeallbuddy(INTEGER);
-- +goose StatementEnd
