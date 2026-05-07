-- AionCore 5.8 — Sprint 1.1a batch 2 port: aion_GetFamiliarList + familiar
-- table widening to NCSoft column set.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetFamiliarList.sql
-- Original (T-SQL):
--   SELECT id, char_id, base_name_id, cur_name_id, name, evolve_cnt,
--          create_time, update_time, safety_flag, growth_point,
--          slot1, slot2, slot3, slot4, slot5, slot6, looting_state
--   FROM user_familiar WITH(NOLOCK)
--   WHERE char_id = @nCharId AND deleted != 1
--
-- Schema delta:
--   Round 7 (00115) scaffolded user_familiar with the bare-minimum columns
--   that aion_DeleteFamiliar touches: (id, char_id, familiar_template_id,
--   name, level, exp, deleted, update_time). The List SP plus the future
--   PutFamiliar / SetFamiliarInfo SPs need the full NCSoft surface, so this
--   migration widens the table additively (every column nullable / defaulted)
--   so existing data and the prior DeleteFamiliar SP keep working untouched.
--
-- Translation notes:
--   * `WITH(NOLOCK)` is a SQL Server read-uncommitted hint; PG has no direct
--     equivalent and dirty-reads are arguably wrong here anyway. PG's MVCC
--     read snapshot already gives the "no blocking" property the original
--     was after, without the dirty-read footgun. STABLE function declaration
--     lets the planner inline this into outer queries when callers join.
--   * `deleted != 1` filter preserved verbatim — soft-deleted familiars stay
--     in the table for a configurable grace window and only vanish from the
--     list while the row is still present.
--   * NCSoft `safety_flag` / `looting_state` are TINYINT; PG side uses
--     SMALLINT (TINYINT doesn't exist in PG; SMALLINT is the smallest int).
--   * `create_time` / `update_time` are BIGINT epoch-millis in NCSoft (set
--     by application code). We keep BIGINT for byte-perfect parity. The
--     existing `update_time` column from 00115 is already BIGINT — no widen.
--
-- Used by:
--   scripts/handlers/cm_familiar_list.lua  -- SM_FAMILIAR_LIST snapshot build
--   scripts/lib/familiar.lua               -- pet bag / inventory query

-- +goose Up

-- +goose StatementBegin
-- Additive widening: every new column has a sensible default so existing
-- rows stay valid; ordering is informational (PG doesn't expose column order
-- to clients in any load-bearing way).
ALTER TABLE user_familiar
    ADD COLUMN IF NOT EXISTS base_name_id  INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cur_name_id   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS evolve_cnt    INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS create_time   BIGINT   NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS safety_flag   SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS growth_point  INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot1         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot2         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot3         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot4         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot5         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS slot6         INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS looting_state SMALLINT NOT NULL DEFAULT 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfamiliarlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getfamiliarlist(_char_id INTEGER)
RETURNS TABLE (
    id            BIGINT,
    char_id       INTEGER,
    base_name_id  INTEGER,
    cur_name_id   INTEGER,
    name          TEXT,
    evolve_cnt    INTEGER,
    create_time   BIGINT,
    update_time   BIGINT,
    safety_flag   SMALLINT,
    growth_point  INTEGER,
    slot1         INTEGER,
    slot2         INTEGER,
    slot3         INTEGER,
    slot4         INTEGER,
    slot5         INTEGER,
    slot6         INTEGER,
    looting_state SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uf.id,
               uf.char_id,
               uf.base_name_id,
               uf.cur_name_id,
               uf.name,
               uf.evolve_cnt,
               uf.create_time,
               uf.update_time,
               uf.safety_flag,
               uf.growth_point,
               uf.slot1, uf.slot2, uf.slot3, uf.slot4, uf.slot5, uf.slot6,
               uf.looting_state
          FROM user_familiar uf
         WHERE uf.char_id = _char_id
           AND uf.deleted <> 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfamiliarlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
ALTER TABLE user_familiar
    DROP COLUMN IF EXISTS looting_state,
    DROP COLUMN IF EXISTS slot6,
    DROP COLUMN IF EXISTS slot5,
    DROP COLUMN IF EXISTS slot4,
    DROP COLUMN IF EXISTS slot3,
    DROP COLUMN IF EXISTS slot2,
    DROP COLUMN IF EXISTS slot1,
    DROP COLUMN IF EXISTS growth_point,
    DROP COLUMN IF EXISTS safety_flag,
    DROP COLUMN IF EXISTS create_time,
    DROP COLUMN IF EXISTS evolve_cnt,
    DROP COLUMN IF EXISTS cur_name_id,
    DROP COLUMN IF EXISTS base_name_id;
-- +goose StatementEnd
