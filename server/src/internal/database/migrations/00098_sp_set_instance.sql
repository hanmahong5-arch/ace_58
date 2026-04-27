-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetInstance.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInstance.sql
-- Upsert one persistent-instance row by instance_id. Called when a long-lived
-- dungeon (e.g. weekly raid lockout) is created or its validity is extended.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstance(INTEGER, INTEGER, INTEGER, VARCHAR);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstance(
    _instance_id   INTEGER,
    _validity_time INTEGER,
    _spawn_page    INTEGER,
    _phase         VARCHAR(1024)
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO instance (instance_id, validity_time, spawn_page, phase_data)
    VALUES (_instance_id, _validity_time, _spawn_page, _phase)
    ON CONFLICT (instance_id) DO UPDATE
       SET validity_time = EXCLUDED.validity_time,
           spawn_page    = EXCLUDED.spawn_page,
           phase_data    = EXCLUDED.phase_data;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstance(INTEGER, INTEGER, INTEGER, VARCHAR);
-- +goose StatementEnd
