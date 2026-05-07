-- AionCore 5.8 — Char 生命周期清理 batch 27 / 5 of 5: aion_DeleteAllSkill.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllSkill.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteAllSkill]
--       @nCharId int
--   as
--   SET NOCOUNT ON
--   DELETE
--   FROM user_skill
--   WHERE char_id=@nCharId
--   set nocount off
--
-- Translation notes:
--   * Wipes every learned skill row for a single character. Cascade
--     helper for character-purge: the sweeper calls this before
--     aion_deletechar to drop the character's learned skills.
--   * NCSoft `SET NOCOUNT ON/OFF` dropped.
--   * NCSoft @nCharId INT → PG INTEGER.
--   * Returns VOID — matches NCSoft no-return contract (sister cascades
--     00276/00277/00278 also VOID).
--   * Does NOT touch user_skill_cooltime or user_skill_skin — the NCSoft
--     cascade calls each one independently:
--       aion_DeleteAllSkill          → user_skill
--       aion_DeleteAllSkillCooltime  → user_skill_cooltime (separate SP)
--       aion_DeleteAllSkillSkin      → user_skill_skin (separate SP)
--     The "do exactly what the comment says" contract is preserved
--     (caller composes the cascade explicitly).
--
-- Bug-for-bug pin:
--   * char_id with no rows → DELETE affects 0 rows, no error. Pinned.
--   * Idempotent — re-invocation on an empty char_id is a no-op.
--   * No FK references TO user_skill (PK is composite (char_id,
--     skill_id) with no outbound references), so the DELETE does not
--     orphan rows elsewhere.
--   * skill_data1 / skill_data2 (skill XP / charge counters) are wiped
--     along with the row — there is no soft-delete for skill XP. NCSoft
--     pinned.
--   * No DELETETOP / batched delete — a character at level 75 has under
--     200 skills, so single-shot DELETE is safe.
--
-- Duplicate note:
--   * 00120 already ports the same SP from Round 10 F1. This entry is
--     the batch-27 char-lifecycle-cleanup sibling carrying expanded
--     audit notes. Function body is byte-identical to 00120 so
--     CREATE OR REPLACE keeps the migrations order-independent.
--
-- Used by:
--   scripts/lib/char_purge.lua                  -- delete-cascade helper
--   scripts/handlers/cm_delete_character.lua    -- explicit char-delete
--   scripts/admin/gm_purge_char.lua              -- GM force-purge tool

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallskill(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id : char to wipe all learned skills for (NCSoft @nCharId INT)
-- 返回 VOID.
CREATE OR REPLACE FUNCTION aion_deleteallskill(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_skill WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallskill(INTEGER);
-- +goose StatementEnd
