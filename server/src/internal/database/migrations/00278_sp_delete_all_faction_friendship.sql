-- AionCore 5.8 — Char 生命周期清理 batch 27 / 3 of 5: aion_DeleteAllFactionFriendship.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllFactionFriendship.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteAllFactionFriendship]
--       @nCharId int
--   as
--   SET NOCOUNT ON
--   DELETE
--   FROM user_faction_friendship
--   WHERE char_id=@nCharId
--   set nocount off
--
-- Translation notes:
--   * Wipes every faction-reputation row for a single character. Distinct
--     from 00086 aion_DeleteFactionFriendship which is a per-(char,
--     faction) soft-delete (sets jointime=0 only). This SP is the
--     character-purge cascade hard-delete that drops every (char_id,*)
--     row — used during the 7-day delete sweeper to free the rows after
--     the char is gone.
--   * NCSoft `SET NOCOUNT ON/OFF` dropped.
--   * NCSoft @nCharId INT → PG INTEGER.
--   * Returns VOID — matches NCSoft no-return contract; sister cascade
--     SPs (00120, 00122) also return VOID.
--   * The DELETE wipes all 5 factionquest_* tracking columns along with
--     friendship/jointime — the row is the unit of deletion, not the
--     individual columns. NCSoft's DELETE FROM is row-level so the
--     factionquest progress is implicitly lost; pinned.
--
-- Bug-for-bug pin:
--   * char_id with no rows → DELETE affects 0 rows, no error. Pinned.
--   * Idempotent — re-running on an already-empty char_id is a no-op.
--   * Composite PK (char_id, faction_id) means a single char can have
--     multiple rows (Elyos faction + Asmodian faction + the four ally
--     factions), and this SP wipes ALL of them in one shot. NCSoft's
--     intent is exactly this; pinned.
--   * No FK references TO user_faction_friendship from other tables, so
--     the DELETE does not orphan any rows elsewhere.
--   * Hard-delete (no soft-delete column) — once gone, the player cannot
--     restore faction reputation by undoing the char-delete. NCSoft's
--     restore path (aion_ClearCharDeleteTime) does NOT recreate
--     faction_friendship rows; if the cascade ran, the data is gone.
--     Pinned (this is the real NCSoft behavior, not a bug to fix).
--
-- Used by:
--   scripts/lib/char_purge.lua                  -- delete-cascade helper
--   scripts/admin/gm_purge_char.lua              -- GM force-purge tool

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallfactionfriendship(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char to wipe all faction-friendship rows for (NCSoft @nCharId INT)
-- 返回 VOID.
CREATE OR REPLACE FUNCTION aion_deleteallfactionfriendship(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_faction_friendship WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallfactionfriendship(INTEGER);
-- +goose StatementEnd
