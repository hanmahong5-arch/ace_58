-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetCharLocation.
--
-- Resolves Round 4 MISSING entry "aion_PutCharLocation" — NCSoft's actual SP
-- name is aion_SetCharLocation. (decision logged in priority-50.md)
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharLocation.sql
-- Body is a 1-line UPDATE — auto-port pass: 100%.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocation(INTEGER, INTEGER, INTEGER, REAL, REAL, REAL);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocation(
    _char_id     INTEGER,
    _cur_server  INTEGER,
    _world       INTEGER,
    _xlocation   REAL,
    _ylocation   REAL,
    _zlocation   REAL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET cur_server = _cur_server,
           world      = _world,
           xlocation  = _xlocation,
           ylocation  = _ylocation,
           zlocation  = _zlocation
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocation(INTEGER, INTEGER, INTEGER, REAL, REAL, REAL);
-- +goose StatementEnd
