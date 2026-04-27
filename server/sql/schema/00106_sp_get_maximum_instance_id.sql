-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetMaximumInstanceId.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetMaximumInstanceId.sql
--
-- Returns the highest "regular" instance_id (< 0x90000000 sentinel — NCSoft
-- reserves the upper 256M ids for system-spawned tournament rooms which must
-- not influence the next-id allocator). Performs two side-effect cleanups:
--   1. delete world_extcondition rows for instances whose validity_time has
--      already expired
--   2. delete the expired instance rows themselves
-- Called by the world engine at boot to seed its instance-id sequence and
-- reap stale records in one round-trip.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmaximuminstanceid(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmaximuminstanceid(_current_time INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    v_max INTEGER;
BEGIN
    -- Compute first so the SELECT happens BEFORE the cleanup DELETEs would
    -- otherwise affect MAX (still safe under MVCC, but matches T-SQL order).
    SELECT COALESCE(MAX(instance_id), 0)
      INTO v_max
      FROM user_instance
     WHERE instance_id < 2415919104;  -- 0x90000000

    -- Reap stale ext-conditions whose owning instance has expired.
    DELETE FROM world_extcondition
     WHERE world_type = 1
       AND world_num IN (SELECT instance_id FROM instance WHERE validity_time < _current_time);

    -- Reap the expired instance rows themselves.
    DELETE FROM instance WHERE validity_time < _current_time;

    RETURN v_max;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmaximuminstanceid(INTEGER);
-- +goose StatementEnd
