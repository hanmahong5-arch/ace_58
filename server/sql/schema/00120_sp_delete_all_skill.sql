-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteAllSkill.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllSkill.sql
--
-- T-SQL body:
--   DELETE FROM user_skill WHERE char_id = @nCharId
--
-- Cascade helper for character-purge. Called by the sweeper before
-- aion_deletechar to drop the character's learned skills. Note that
-- user_skill_cooltime and user_skill_skin are managed by separate SPs
-- (the original NCSoft cascade calls each one independently — preserving
-- the "do exactly what the comment says" contract).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallskill(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
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
