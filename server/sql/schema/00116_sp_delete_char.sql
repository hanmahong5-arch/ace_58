-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteChar.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteChar.sql
--
-- Original T-SQL body is a single line:
--   DELETE user_data WHERE char_id = @nCharId
--
-- This is the FINAL purge invoked by the nightly sweeper after the 7-day
-- soft-delete grace window expires (delete_date <= now AND
-- delete_complete_date = 0). The handler-side flow is:
--
--   1. CM_DELETE_CHARACTER  → aion_setchardeletetime(char_id, now+7days)
--   2. (… 7 days pass …)
--   3. sweeper job          → aion_getdeletedcharlist(server_id, now)
--                          → for each row: aion_deletechar(char_id) +
--                                          cascade-Delete helpers
--
-- The original NCSoft SP intentionally does NOT cascade-clean child tables
-- (user_item, user_skill, user_quest, …); the calling sweeper invokes the
-- per-table DeleteAll* SPs separately so that an admin can resurrect a
-- character mid-sweep just by reverting the user_data DELETE. We preserve
-- that behaviour verbatim — the cascade is the sweeper's job, not this SP's.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletechar(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletechar(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_data WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletechar(INTEGER);
-- +goose StatementEnd
