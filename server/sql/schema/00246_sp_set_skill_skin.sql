-- AionCore 5.8 — Sprint 1.1a batch 22 port: aion_SetSkillSkin
-- (mutate use_skin / expire_time on an existing skill-skin row by command).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetSkillSkin.sql
-- Original (T-SQL):
--   IF @command_type = 3  -- USE   (장착)
--     UPDATE user_skill_skin SET use_skin = 1
--      WHERE char_id = @char_id AND skill_skin_id = @skill_skin_id
--   IF @command_type = 4  -- DIUSE (해제)
--     UPDATE user_skill_skin SET use_skin = 0
--      WHERE char_id = @char_id AND skill_skin_id = @skill_skin_id
--   IF @command_type = 5  -- EXPIRE (만료)
--     UPDATE user_skill_skin SET use_skin = 0, expire_time = 0
--      WHERE char_id = @char_id AND skill_skin_id = @skill_skin_id
--
-- Schema:
--   user_skill_skin already created in 00032 (pve scaffold) with PK
--   (char_id, skill_skin_id). We DO NOT re-create. SetSkillSkin only
--   mutates existing rows — PutSkillSkin (00041) is the upsert path.
--
-- Translation notes:
--   * NCSoft uses three IF-branches over @command_type to avoid a CASE
--     statement. We keep the ladder verbatim (no consolidation into a
--     single CASE update) so the bug-for-bug matrix is observable:
--       command_type = 3 → equip      (use_skin := 1)
--       command_type = 4 → unequip    (use_skin := 0)
--       command_type = 5 → expire     (use_skin := 0, expire_time := 0)
--       any other value → no-op (no UPDATE, no error) — pinned
--   * tinyint → SMALLINT (PG has no TINYINT). NCSoft tinyint is unsigned
--     0..255; we accept SMALLINT 0..32767. Realistic input domain matches.
--   * smallint @skill_skin_id → INTEGER for parameter convenience (matches
--     00041 PutSkillSkin signature; cast to SMALLINT internally to align
--     with the column type).
--   * VOID return — NCSoft contract has no result set, no return.
--
-- Bug-for-bug:
--   * The three IFs run sequentially, NOT mutually exclusive in the body.
--     NCSoft picked literal IF-checks rather than IF-ELSE — but since
--     command_type is a single value, only one branch's predicate can be
--     true at a time. Pinned: ladder kept literal.
--   * `expire_time = 0` on EXPIRE branch matches the read-side filter in
--     00168 GetSkillSkinList (`expire_time > 0`) — a 0 row becomes
--     invisible to the login hydrator. Pinned semantics verified.
--   * Updating a non-existent (char_id, skill_skin_id) is a silent no-op
--     (UPDATE of zero rows). NCSoft never validated. Pinned.
--   * Unknown command_type values (0/1/2/6/…) silently no-op. Pinned —
--     this is intentional defensive behavior in the NCSoft client.
--
-- Used by:
--   scripts/handlers/cm_skill_skin_command.lua  -- player-issued equip/unequip
--   scripts/events/on_skill_skin_expire.lua     -- timer-driven EXPIRE branch

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setskillskin(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id        : owning char_id (PK part 1)
-- _skill_skin_id  : skin catalog id (PK part 2; T-SQL smallint widened)
-- _command_type   : 3=USE, 4=DIUSE, 5=EXPIRE; any other value is silently a no-op
CREATE OR REPLACE FUNCTION aion_setskillskin(
    _char_id       INTEGER,
    _skill_skin_id INTEGER,
    _command_type  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- USE — equip the skin (does not extend expire_time).
    IF _command_type = 3 THEN
        UPDATE user_skill_skin
           SET use_skin = 1
         WHERE char_id       = _char_id
           AND skill_skin_id = _skill_skin_id::SMALLINT;
    END IF;

    -- DIUSE — unequip but keep entitlement (expire_time intact).
    IF _command_type = 4 THEN
        UPDATE user_skill_skin
           SET use_skin = 0
         WHERE char_id       = _char_id
           AND skill_skin_id = _skill_skin_id::SMALLINT;
    END IF;

    -- EXPIRE — server-driven timeout: clear use_skin AND zero expire_time.
    -- A zero expire_time hides the row from 00168 GetSkillSkinList.
    IF _command_type = 5 THEN
        UPDATE user_skill_skin
           SET use_skin    = 0,
               expire_time = 0
         WHERE char_id       = _char_id
           AND skill_skin_id = _skill_skin_id::SMALLINT;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setskillskin(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
