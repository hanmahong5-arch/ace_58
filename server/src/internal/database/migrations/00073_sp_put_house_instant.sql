-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_PutHouseInstant.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutHouseInstant.sql
--
-- Inserts a fresh house_instant row when a player first acquires a house cell.
-- Both update_time and created_time are stamped to NOW() (mirrors GETDATE()).
-- T-SQL had no explicit upsert here — the caller checks GetHouseInstant first.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseinstant(INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthouseinstant(
    _id          INTEGER,
    _state       SMALLINT,
    _permission  SMALLINT,
    _inwall      INTEGER,
    _infloor     INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO house_instant (id, state, permission, inwall, infloor, update_time, created_time)
    VALUES (_id, _state, _permission, _inwall, _infloor, NOW(), NOW());
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseinstant(INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
