-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_GetSkillCooltime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetSkillCooltime.sql
-- Returns the persisted skill-cooldown blob for one character.
-- The blob (varbinary in T-SQL → BYTEA in PG) is opaque to the SP — the
-- world server is responsible for encoding/decoding cooldowns into the byte
-- array (one record per active CD; format is 8-byte record × cnt).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillcooltime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskillcooltime(_char_id INTEGER)
RETURNS TABLE (cooltime_data_cnt SMALLINT, data BYTEA)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT usc.cooltime_data_cnt, usc.data
          FROM user_skill_cooltime usc
         WHERE usc.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillcooltime(INTEGER);
-- +goose StatementEnd
