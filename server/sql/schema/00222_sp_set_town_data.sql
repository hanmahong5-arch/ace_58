-- AionCore 5.8 — Sprint 1.1a batch 17 port: aion_SetTownData (town-level UPSERT, server-wide).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetTownData.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT town_id FROM town_data(updlock) WHERE town_id = @town_id)
--       UPDATE town_data
--       SET point = @point,
--           lastLvChangedTime = @lastLvChangedTime
--       WHERE town_id = @town_id
--   ELSE
--       INSERT town_data VALUES (@town_id, @point, @lastLvChangedTime)
--
-- Schema delta:
--   First port to touch town_data — table does not yet exist in PG.
--   town_data is a SERVER-WIDE singleton-per-town table (NOT keyed by
--   char_id). Each row tracks the cumulative town point + last-leveled
--   timestamp for one of the in-game towns (Pandaemonium, Sanctum, etc.).
--   NCSoft column types from raw schema:
--       town_id            INT  (PK; town catalog id)
--       point              INT  (cumulative town-investment points)
--       lastLvChangedTime  INT  (epoch seconds; suffers 2038 overflow —
--                                NCSoft uses signed-int epoch column,
--                                pinned verbatim).
--   NCSoft column name `lastLvChangedTime` is camelCase — preserved verbatim
--   and quoted in DDL/SQL so PG keeps the case (matches the 00211
--   user_item_sealed precedent for sealExpiredTime).
--
-- Translation notes:
--   * IF EXISTS … UPDATE … ELSE INSERT collapses to ON CONFLICT (town_id).
--     The T-SQL UPDLOCK hint maps to PG's row-level lock on conflict
--     resolution (UPSERT auto-serializes per row).
--   * Returns rows-affected (always 1 on success).
--   * VOLATILE — data-modifying.
--   * No char_id parameter — this is a server-state SP, NOT per-char.
--     The 5.8 town-system world bot reaches the SP from a worldwide tick
--     when a town's investment threshold is crossed.
--
-- Bug-for-bug:
--   * No clamp on `point` (negative is technically representable in T-SQL
--     INT; NCSoft accepts it for GM rollback corrections). Pinned — do
--     NOT add a CHECK (point >= 0) constraint.
--   * `lastLvChangedTime` is INTEGER (epoch seconds) → 2038 overflow lives
--     in the schema. Pinned verbatim; the 5.8 client cannot consume a
--     wider type without a protocol shift.
--   * No catalog FK — town_id values are validated by gameplay code, not
--     by the table. Allows pre-shipping a town_id ahead of catalog rollout.
--
-- Used by:
--   scripts/lib/town.lua                       (town-state mutators)
--   scripts/events/world_tick_town_level.lua   (level-up commit)

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- town_data — first introduction. PK on town_id. Quoted camelCase
-- column `lastLvChangedTime` preserves NCSoft naming verbatim.
-- ====================================================================
CREATE TABLE IF NOT EXISTS town_data (
    town_id              INTEGER PRIMARY KEY,
    point                INTEGER NOT NULL DEFAULT 0,
    "lastLvChangedTime"  INTEGER NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settowndata(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settowndata(
    _town_id              INTEGER,
    _point                INTEGER,
    _last_lv_changed_time INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on PK(town_id). The T-SQL IF EXISTS branch and ELSE branch
    -- both observably emit @@ROWCOUNT = 1; the PG UPSERT collapses both
    -- to a single statement with identical observable behaviour.
    INSERT INTO town_data (town_id, point, "lastLvChangedTime")
    VALUES (_town_id, _point, _last_lv_changed_time)
    ON CONFLICT (town_id) DO UPDATE SET
        point               = EXCLUDED.point,
        "lastLvChangedTime" = EXCLUDED."lastLvChangedTime";
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settowndata(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS town_data;
-- +goose StatementEnd
