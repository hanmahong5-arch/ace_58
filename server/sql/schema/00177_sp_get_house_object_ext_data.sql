-- AionCore 5.8 — Sprint 1.1a batch 8 port: aion_GetHouseObjectExtData.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetHouseObjectExtData.sql
-- Original (T-SQL):
--   SELECT obj_id, char_id, accumulated_usecount, next_resettime_for_owner,
--          resource_id, account_id, cur_owner_usecnt_per_day
--   FROM houseobject_extdata WHERE char_id = @char_id
--
-- Translation notes:
--   * `houseobject_extdata` is the per-char "extra data" sidecar for
--     placeable house objects. The base houseobject row lives elsewhere; this
--     table tracks usage counters and ownership-history-style fields that
--     would bloat the parent row if inlined. Layout per NCSoft 5.8 schema:
--       - obj_id                       INT     : house object instance id
--       - char_id                      INT     : current owner char (filter key)
--       - accumulated_usecount         INT     : lifetime use counter
--       - next_resettime_for_owner     BIGINT  : unix epoch seconds; daily-cap reset
--       - resource_id                  INT     : 5.8 catalog resource id (immutable)
--       - account_id                   INTEGER : owner account (for cross-char ownership transfer audit)
--       - cur_owner_usecnt_per_day     INT     : daily-cap counter (resets at next_resettime_for_owner)
--   * No ORDER BY in T-SQL source — preserved as-is. The 5.8 client iterates
--     the result set and indexes by obj_id internally, so order is don't-care.
--   * Function declared STABLE — pure read.
--
-- Used by:
--   scripts/handlers/cm_house_object_ext_data_get.lua  -- on house enter / object placement

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS houseobject_extdata (
    obj_id                    INTEGER PRIMARY KEY,
    char_id                   INTEGER NOT NULL,
    accumulated_usecount      INTEGER NOT NULL DEFAULT 0,
    next_resettime_for_owner  BIGINT  NOT NULL DEFAULT 0,
    resource_id               INTEGER NOT NULL DEFAULT 0,
    account_id                INTEGER NOT NULL DEFAULT 0,
    cur_owner_usecnt_per_day  INTEGER NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_houseobject_extdata_char ON houseobject_extdata(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectextdata(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseobjectextdata(_char_id INTEGER)
RETURNS TABLE (
    obj_id                    INTEGER,
    char_id                   INTEGER,
    accumulated_usecount      INTEGER,
    next_resettime_for_owner  BIGINT,
    resource_id               INTEGER,
    account_id                INTEGER,
    cur_owner_usecnt_per_day  INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT hoe.obj_id,
               hoe.char_id,
               hoe.accumulated_usecount,
               hoe.next_resettime_for_owner,
               hoe.resource_id,
               hoe.account_id,
               hoe.cur_owner_usecnt_per_day
          FROM houseobject_extdata hoe
         WHERE hoe.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseobjectextdata(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_houseobject_extdata_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS houseobject_extdata;
-- +goose StatementEnd
