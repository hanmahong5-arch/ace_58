-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetHouseObjectInstant.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetHouseObjectInstant.sql
--
-- Returns ALL active (state != 0) personal-housing (owner_type = 1) objects
-- belonging to the given user.  ISNULL → COALESCE for dye_info / expire_dye_time.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectinstant(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseobjectinstant(
    _user_id INTEGER
)
RETURNS TABLE (
    out_id                BIGINT,
    out_object_nameid     INTEGER,
    out_object_type       SMALLINT,
    out_owner_id          INTEGER,
    out_owner_type        SMALLINT,
    out_state             SMALLINT,
    out_expired_time      INTEGER,
    out_general_use_count INTEGER,
    out_world             INTEGER,
    out_xlocation         REAL,
    out_ylocation         REAL,
    out_zlocation         REAL,
    out_dir               SMALLINT,
    out_dye_info          INTEGER,
    out_expire_dye_time   INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT id, object_nameid, object_type, owner_id, owner_type, state,
           expired_time, general_use_count, world, xlocation, ylocation, zlocation, dir,
           COALESCE(dye_info, 0)::INTEGER,
           COALESCE(expire_dye_time, 0)::INTEGER
      FROM houseobject
     WHERE owner_type = 1 AND owner_id = _user_id AND state <> 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectinstant(INTEGER);
-- +goose StatementEnd
