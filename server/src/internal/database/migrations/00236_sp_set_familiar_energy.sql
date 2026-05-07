-- AionCore 5.8 — Sprint 1.1a batch 20 port: aion_SetFamiliarEnergy
-- (UPSERT user_data_ext.familiar_energy + autocharge flag; first introduction
-- of the user_data_ext side-table).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFamiliarEnergy.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = @char_id)
--       UPDATE user_data_ext
--       SET familiar_energy = @familiarEnergy,
--           familiar_energy_autocharge = @familiarEnergyAutoCharge,
--           last_summon_familiar = @familiarEnergy
--       WHERE char_id = @char_id
--   ELSE
--       INSERT into user_data_ext (char_id, familiar_energy,
--                                  familiar_energy_autocharge, last_summon_familiar)
--       VALUES (@char_id, @familiarEnergy, @familiarEnergyAutoCharge, @familiarEnergy)
--
-- Schema:
--   `user_data_ext` is **first introduced here** — it is a 1:1 side-table
--   on user_data (PK = char_id). NCSoft uses it as the catch-all "wide row"
--   extension so the hot user_data table doesn't grow unbounded for cold
--   per-character flags (familiar/luna/cosmetic counters etc.). Subsequent
--   batches that touch other ext columns will widen this table with
--   IF NOT EXISTS additive ALTERs (see 00148 widening of user_familiar
--   for the pattern).
--
-- Translation notes:
--   * NCSoft IF EXISTS + UPDLOCK pattern is a "manual UPSERT" with a
--     hold-the-row-lock-while-checking trick (race-safe under SQL Server's
--     pessimistic locking). PG equivalent is INSERT ... ON CONFLICT DO
--     UPDATE — concurrency-safe via the unique-PK constraint, no manual
--     lock dance needed. Behaviour is functionally identical for the
--     happy path.
--   * `last_summon_familiar = @familiarEnergy` is the well-known **NCSoft
--     bug-for-bug pin**: writing the *energy reservoir* into a column
--     named `last_summon_familiar` is semantically wrong (the latter
--     should hold an entity id or timestamp). Live NCSoft has shipped
--     this for years; downstream callers (engine code) treat the column
--     as opaque. Pinned exactly — DO NOT "fix" it. If a future sprint
--     wants to reclaim the column, that is a separate decision with a
--     migration of its own; this SP must mirror live behaviour.
--   * @familiarEnergy is INT (signed); large integers fit. PG INTEGER
--     mirrors range exactly.
--   * @familiarEnergyAutoCharge is TINYINT (0/1) → SMALLINT.
--   * VOLATILE (data-modifying). No return value.
--
-- Bug-for-bug:
--   * The bizarre `last_summon_familiar = @familiarEnergy` triple-write
--     is preserved verbatim — see Translation note above.
--   * No FK from user_data_ext.char_id → user_data.char_id at the NCSoft
--     side either; pinned (orphan-tolerant). The INSERT branch on a
--     missing user_data row would still succeed.
--   * The original INSERT branch only writes 4 columns (char_id +
--     3 familiar columns); other ext columns receive PG defaults. Pinned.
--
-- Used by:
--   scripts/handlers/cm_familiar_summon.lua  -- summon / despawn energy refund
--   scripts/lib/familiar.lua                 -- energy regen tick

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_data_ext — first introduction. 1:1 side-table on user_data (PK =
-- char_id). Hosts cold per-character flags (currently familiar energy +
-- autocharge; future batches widen additively).
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_data_ext (
    char_id                     INTEGER PRIMARY KEY,
    familiar_energy             INTEGER NOT NULL DEFAULT 0,
    familiar_energy_autocharge  SMALLINT NOT NULL DEFAULT 0,
    last_summon_familiar        INTEGER NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarenergy(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id                       : owning char_id (PK on user_data_ext)
-- _familiar_energy               : energy reservoir (also written into
--                                  last_summon_familiar — see bug-for-bug)
-- _familiar_energy_autocharge    : 0/1 autocharge toggle (TINYINT → SMALLINT)
CREATE OR REPLACE FUNCTION aion_setfamiliarenergy(
    _char_id                     INTEGER,
    _familiar_energy             INTEGER,
    _familiar_energy_autocharge  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Manual UPSERT (T-SQL IF EXISTS + UPDLOCK) → PG ON CONFLICT.
    -- Race-safe via PK, equivalent to the live NCSoft happy path.
    INSERT INTO user_data_ext
           (char_id, familiar_energy, familiar_energy_autocharge,
            last_summon_familiar)
    VALUES (_char_id, _familiar_energy, _familiar_energy_autocharge,
            _familiar_energy)  -- NCSoft pin: last_summon_familiar = energy
    ON CONFLICT (char_id) DO UPDATE
       SET familiar_energy            = EXCLUDED.familiar_energy,
           familiar_energy_autocharge = EXCLUDED.familiar_energy_autocharge,
           last_summon_familiar       = EXCLUDED.familiar_energy;  -- pinned
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarenergy(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_data_ext;
-- +goose StatementEnd
