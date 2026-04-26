-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_PutSkill.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutSkill.sql
-- Upsert (char_id, skill_id) — T-SQL used IF EXISTS / UPDATE / ELSE INSERT.
-- PG idiom: INSERT ... ON CONFLICT DO UPDATE.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskill(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskill(
    _char_id INTEGER, _skill_id INTEGER,
    _skill_data1 INTEGER, _skill_data2 INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_skill (char_id, skill_id, skill_data1, skill_data2)
    VALUES (_char_id, _skill_id, _skill_data1, _skill_data2)
    ON CONFLICT (char_id, skill_id) DO UPDATE
       SET skill_data1 = EXCLUDED.skill_data1,
           skill_data2 = EXCLUDED.skill_data2;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskill(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
