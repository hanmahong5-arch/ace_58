-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetWorldExtCondition.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetWorldExtCondition.sql
-- Sibling of SetInstanceCondition (00100) for persistent-world rows
-- (world_type=0). Same two-stage hash → text disambiguation.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setworldextcondition(INTEGER, VARCHAR, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setworldextcondition(
    _world_num     INTEGER,
    _variable      VARCHAR(256),
    _variable_hash INTEGER,
    _value         INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_id        BIGINT := 0;
    v_match_cnt INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_match_cnt
      FROM world_extcondition
     WHERE world_type = 0 AND world_num = _world_num AND variable_hash = _variable_hash;

    IF v_match_cnt > 1 THEN
        SELECT id INTO v_id
          FROM world_extcondition
         WHERE world_type = 0 AND world_num = _world_num AND variable = _variable
         LIMIT 1;
    ELSIF v_match_cnt = 1 THEN
        SELECT id INTO v_id
          FROM world_extcondition
         WHERE world_type = 0 AND world_num = _world_num AND variable_hash = _variable_hash
         LIMIT 1;
    END IF;

    IF v_id IS NOT NULL AND v_id <> 0 THEN
        UPDATE world_extcondition SET value = _value WHERE id = v_id;
    ELSE
        INSERT INTO world_extcondition (world_type, world_num, variable, variable_hash, value)
        VALUES (0, _world_num, _variable, _variable_hash, _value);
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setworldextcondition(INTEGER, VARCHAR, INTEGER, INTEGER);
-- +goose StatementEnd
