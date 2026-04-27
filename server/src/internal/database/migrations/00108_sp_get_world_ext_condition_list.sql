-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetWorldExtConditionList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetWorldExtConditionList.sql
-- Sibling of GetInstanceCondition (00099) but returns persistent-world rows
-- (world_type=0). World engine loads these once at boot to rehydrate global
-- per-zone state (e.g. seasonal event timers, kill-tally counters).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getworldextconditionlist();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getworldextconditionlist()
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
     WHERE wec.world_type = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getworldextconditionlist();
-- +goose StatementEnd
