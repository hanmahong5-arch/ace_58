-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_PutHouseObject.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutHouseObject.sql
--
-- Inserts a new houseobject row and returns the freshly minted BIGSERIAL id
-- (mirrors @@IDENTITY). Returns 0 when the insert fails (caller treats 0 as
-- "out of inventory slot" / fail).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseobject(INTEGER, SMALLINT, INTEGER, SMALLINT, SMALLINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthouseobject(
    _object_nameid INTEGER,
    _object_type   SMALLINT,
    _owner_id      INTEGER,
    _owner_type    SMALLINT,
    _state         SMALLINT,
    _expired_time  INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    new_id BIGINT;
BEGIN
    INSERT INTO houseobject
           (object_nameid, object_type, owner_id, owner_type, state, expired_time, update_time, created_time)
    VALUES (_object_nameid, _object_type, _owner_id, _owner_type, _state, _expired_time, NOW(), NOW())
    RETURNING id INTO new_id;
    RETURN new_id;
EXCEPTION WHEN others THEN
    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthouseobject(INTEGER, SMALLINT, INTEGER, SMALLINT, SMALLINT, INTEGER);
-- +goose StatementEnd
