-- AionCore 5.8 — Sprint 1.1a batch 3 port: aion_ChangeBuddyComment.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ChangeBuddyComment.sql
-- Original (T-SQL):
--   UPDATE user_buddy1 SET comment = @Comment
--    WHERE char_id = @nCharId AND buddy_id = @nBuddyId
--
-- Schema delta:
--   00144 scaffolded user_buddy_list with the bare-minimum columns the AddBuddy
--   path touches (char_id, buddy_id, delete_flag, create_date). NCSoft's
--   user_buddy1 table has an additional `comment nvarchar(64) NULL` column —
--   used by the friend UI to let players annotate friends ("Tank — alt of X").
--   We widen additively: every existing row gets DEFAULT '' so AddBuddy /
--   GetBuddyIdList keep working untouched.
--
-- Translation notes:
--   * NCSoft column was nvarchar(64) NULL with NULL semantics ("no comment yet").
--     PG side uses TEXT NOT NULL DEFAULT '' to mirror the rest of the
--     user_data text-column convention (no NULL noise downstream). Empty string
--     is the canonical "no comment" sentinel; the SP overwrites unconditionally
--     so existing NULLs never leak through.
--   * Returns rows-affected (0 = no such pair, 1 = updated). Caller uses this
--     to decide whether to push SM_FRIEND_LIST refresh; T-SQL had no return
--     value but Lua callers benefit from the rowcount.
--
-- Used by: scripts/handlers/cm_change_buddy_comment.lua (future) — invoked
-- when the player edits a friend's note from the social panel.

-- +goose Up
-- +goose StatementBegin
ALTER TABLE user_buddy_list
    ADD COLUMN IF NOT EXISTS comment TEXT NOT NULL DEFAULT '';
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_change_buddy_comment(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_change_buddy_comment(
    _char_id  INTEGER,
    _buddy_id INTEGER,
    _comment  TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    updated_cnt INTEGER;
BEGIN
    UPDATE user_buddy_list
       SET comment = _comment
     WHERE char_id  = _char_id
       AND buddy_id = _buddy_id;
    GET DIAGNOSTICS updated_cnt = ROW_COUNT;
    RETURN updated_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_change_buddy_comment(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_buddy_list DROP COLUMN IF EXISTS comment;
-- +goose StatementEnd
