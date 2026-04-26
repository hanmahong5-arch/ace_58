-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_PutSkillCooltime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutSkillCooltime.sql
-- Persists the skill-cooldown blob on logout (or periodic flush). T-SQL form
-- is exists-then-update-or-insert under UPDLOCK; PG translation is the
-- atomic INSERT … ON CONFLICT DO UPDATE pattern. Char_id is the PK so
-- the conflict target is unambiguous.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillcooltime(INTEGER, INTEGER, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskillcooltime(
    _char_id           INTEGER,
    _cooltime_data_cnt INTEGER,  -- T-SQL smallint widened for client convenience
    _data              BYTEA
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_skill_cooltime (char_id, cooltime_data_cnt, data)
    VALUES (_char_id, _cooltime_data_cnt::SMALLINT, _data)
    ON CONFLICT (char_id) DO UPDATE SET
        cooltime_data_cnt = EXCLUDED.cooltime_data_cnt,
        data              = EXCLUDED.data;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillcooltime(INTEGER, INTEGER, BYTEA);
-- +goose StatementEnd
