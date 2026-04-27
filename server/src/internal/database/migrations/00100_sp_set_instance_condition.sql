-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetInstanceCondition.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInstanceCondition.sql
-- Upsert a single (instance_id, variable_hash) → value mapping with a duplicate
-- disambiguation step: if multiple rows share variable_hash (CRC32 collision)
-- the original SP re-queries by the human-readable `variable` column.
-- We replicate the two-stage lookup verbatim because some scripts depend on
-- both rows existing (NCSoft never added a UNIQUE on variable_hash).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstancecondition(INTEGER, VARCHAR, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstancecondition(
    _instance_id    INTEGER,
    _variable       VARCHAR(256),
    _variable_hash  INTEGER,
    _value          INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_id        BIGINT := 0;
    v_match_cnt INTEGER;
BEGIN
    -- First try by hash; count matching rows so we can disambiguate.
    SELECT COUNT(*) INTO v_match_cnt
      FROM world_extcondition
     WHERE world_type = 1 AND world_num = _instance_id AND variable_hash = _variable_hash;

    IF v_match_cnt > 1 THEN
        -- Collision: pick the row whose readable variable name actually matches.
        SELECT id INTO v_id
          FROM world_extcondition
         WHERE world_type = 1 AND world_num = _instance_id AND variable = _variable
         LIMIT 1;
    ELSIF v_match_cnt = 1 THEN
        SELECT id INTO v_id
          FROM world_extcondition
         WHERE world_type = 1 AND world_num = _instance_id AND variable_hash = _variable_hash
         LIMIT 1;
    END IF;

    IF v_id IS NOT NULL AND v_id <> 0 THEN
        UPDATE world_extcondition SET value = _value WHERE id = v_id;
    ELSE
        INSERT INTO world_extcondition (world_type, world_num, variable, variable_hash, value)
        VALUES (1, _instance_id, _variable, _variable_hash, _value);
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstancecondition(INTEGER, VARCHAR, INTEGER, INTEGER);
-- +goose StatementEnd
