-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetInstance.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInstance.sql
-- Loads every still-valid instance row (validity_time > now). The world engine
-- calls this once at boot to rehydrate the in-memory PERSISTENT_INSTANCE map.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstance(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstance(_current_time INTEGER)
RETURNS TABLE (
    out_instance_id   INTEGER,
    out_validity_time INTEGER,
    out_spawn_page    INTEGER,
    out_phase_data    VARCHAR(1024)
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT i.instance_id, i.validity_time, i.spawn_page, i.phase_data
      FROM instance i
     WHERE i.validity_time > _current_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstance(INTEGER);
-- +goose StatementEnd
