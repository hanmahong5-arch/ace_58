-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetInstanceCondition.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInstanceCondition.sql
-- Loads every (variable, value) pair attached to currently-valid instances.
-- Subquery filters: world_extcondition.world_type=1 (instance) AND world_num
-- IN (still-valid instance_ids). World engine merges these into the rehydrated
-- instance map so per-instance script state survives restarts.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstancecondition(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstancecondition(_current_time INTEGER)
RETURNS TABLE (
    out_world_num INTEGER,
    out_variable  VARCHAR(256),
    out_value     INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT wec.world_num, wec.variable, wec.value
      FROM world_extcondition wec
     WHERE wec.world_type = 1
       AND wec.world_num IN (
           SELECT i.instance_id FROM instance i WHERE i.validity_time > _current_time
       );
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstancecondition(INTEGER);
-- +goose StatementEnd
