-- AionCore 5.8 — batch 29 / 1 of 5 ("Client-data cleanup + single-row abnormal"):
--   aion_DeleteAbnormalStatus — wipe ONE abnormal_status row by (char, abnormal).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAbnormalStatus.sql
-- Original (T-SQL):
--   CREATE procedure [dbo].[aion_DeleteAbnormalStatus]
--       @nCharId int,
--       @nSkillId int
--   as
--   SET NOCOUNT ON
--   DELETE user_abnormal_status
--   WHERE  char_id=@nCharId and skill_id=@nSkillId
--   SET NOCOUNT OFF
--
-- Translation notes:
--   * PG schema (00115 + later add of `skill_id`) carries BOTH `abnormal_id`
--     (PK partner with char_id) AND `skill_id` (own UNIQUE with char_id).
--     NCSoft filters on `skill_id`, so the PG port MUST also filter on
--     `skill_id` — not abnormal_id. Param name `_skill_id` mirrors NCSoft
--     @nSkillId.
--   * Sibling of 00277 (DeleteAllAbnormalStatus, whole-char wipe). This is
--     the per-skill variant — used for buff expiry and buff-cancel actions.
--   * Returns INTEGER rows-affected (0 or 1; UNIQUE(char_id, skill_id) caps
--     the match count). Strict widening of NCSoft VOID, matches batch-27/28
--     convention.
--
-- Bug-for-bug:
--   * Char with no matching abnormal row → 0, silent (no error). Pinned.
--   * No FK guard on char_id — purged char passing stale skill_id is a
--     no-op. Pinned.
--
-- Used by:
--   scripts/handlers/cm_skill_cancel.lua  -- player-cancel buff
--   scripts/events/on_buff_expire.lua     -- timer-tick expire
--   scripts/admin/gm_remove_buff.lua      -- GM single-buff removal

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteabnormalstatus(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id  : NCSoft @nCharId.
-- _skill_id : NCSoft @nSkillId (filter on the skill_id column, not abnormal_id —
--             see header for the column-disambiguation note).
-- Returns 1 if a row was deleted, 0 otherwise.
CREATE OR REPLACE FUNCTION aion_deleteabnormalstatus(
    _char_id  INTEGER,
    _skill_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    n INTEGER;
BEGIN
    DELETE FROM user_abnormal_status
     WHERE char_id  = _char_id
       AND skill_id = _skill_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteabnormalstatus(INTEGER, INTEGER);
-- +goose StatementEnd
