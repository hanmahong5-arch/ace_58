-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_SetHouseObject.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetHouseObject.sql
--
-- Updates an existing houseobject row in-place by id. Stamps update_time = NOW().
-- All 14 mutable columns are overwritten (caller passes the whole row back).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobject(BIGINT, INTEGER, SMALLINT, INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, REAL, REAL, REAL, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseobject(
    _id                BIGINT,
    _object_nameid     INTEGER,
    _object_type       SMALLINT,
    _owner_id          INTEGER,
    _owner_type        SMALLINT,
    _state             SMALLINT,
    _expired_time      INTEGER,
    _general_use_count INTEGER,
    _world             INTEGER,
    _xlocation         REAL,
    _ylocation         REAL,
    _zlocation         REAL,
    _dir               SMALLINT,
    _dye_info_value    INTEGER,
    _dye_expire_time   INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE houseobject
       SET object_nameid     = _object_nameid,
           object_type       = _object_type,
           owner_id          = _owner_id,
           owner_type        = _owner_type,
           state             = _state,
           expired_time      = _expired_time,
           general_use_count = _general_use_count,
           world             = _world,
           xlocation         = _xlocation,
           ylocation         = _ylocation,
           zlocation         = _zlocation,
           dir               = _dir,
           dye_info          = _dye_info_value,
           expire_dye_time   = _dye_expire_time,
           update_time       = NOW()
     WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobject(BIGINT, INTEGER, SMALLINT, INTEGER, SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, REAL, REAL, REAL, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
