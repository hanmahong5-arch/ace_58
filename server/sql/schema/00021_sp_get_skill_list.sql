-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetSkillList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetSkillList.sql
-- Returns all known skills for a char on enter-world.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskilllist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskilllist(_char_id INTEGER)
RETURNS TABLE (skill_id INTEGER, skill_data1 INTEGER, skill_data2 INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT s.skill_id, s.skill_data1, s.skill_data2
      FROM user_skill s
     WHERE s.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskilllist(INTEGER);
-- +goose StatementEnd
