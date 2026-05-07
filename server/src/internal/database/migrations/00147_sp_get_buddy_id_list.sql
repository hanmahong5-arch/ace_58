-- AionCore 5.8 — Sprint 1.1a batch 2 port: aion_GetBuddyIdList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetBuddyIdList.sql
-- Original (T-SQL):
--   SELECT buddy_id FROM user_buddy1 WHERE char_id = @nCharId
--
-- Translation notes:
--   * Filters delete_flag = 0 — the NCSoft proc relied on RemoveBuddy to do
--     the delete; we mirror the soft-delete protocol (see 00144) so the read
--     side has to skip flagged-deleted rows. NCSoft's own version was missing
--     this filter (a 17-year-old bug that surfaces stale "ghost" friends in
--     the UI when RemoveBuddy soft-deletes); we tighten on the PG side.
--   * Returns 0 rows when char has no buddies — caller iterates over Rows.
--   * STABLE function: no writes, only depends on table state, safe to inline
--     in PG planner.
--
-- Used by:
--   scripts/handlers/cm_get_friend_list.lua  -- SM_FRIEND_LIST snapshot build
--   scripts/lib/buddy.lua                    -- broadcast notify-buddy-online

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbuddyidlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbuddyidlist(_char_id INTEGER)
RETURNS TABLE (
    buddy_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ubl.buddy_id
          FROM user_buddy_list ubl
         WHERE ubl.char_id     = _char_id
           AND ubl.delete_flag = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbuddyidlist(INTEGER);
-- +goose StatementEnd
