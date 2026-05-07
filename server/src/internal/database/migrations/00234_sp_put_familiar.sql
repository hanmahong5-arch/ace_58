-- AionCore 5.8 — Sprint 1.1a batch 20 port: aion_PutFamiliar
-- (insert a new familiar row; returns BIGSERIAL id mirroring @@IDENTITY).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutFamiliar.sql
-- Original (T-SQL):
--   INSERT user_familiar (char_id, base_name_id, cur_name_id, name, evolve_cnt,
--                         create_time, update_time, safety_flag, growth_point,
--                         slot1, slot2, slot3, slot4, slot5, slot6,
--                         looting_state, deleted)
--   VALUES (@masterId, @baseNameId, @curNameId, @name, @evolveCnt,
--           @createTime, @updateTime, @safetyFlag, @growthPoint,
--           @slot1, @slot2, @slot3, @slot4, @slot5, @slot6,
--           @lootingState, 0)
--   IF @@ERROR <> 0 RETURN 0
--   RETURN @@IDENTITY
--
-- Schema:
--   user_familiar already widened by 00148 (GetFamiliarList) to the full
--   NCSoft column set. No additional ALTER TABLE needed here. PutFamiliar
--   is the canonical write companion of the read SP, so the column shape
--   is already canonical.
--
-- Translation notes:
--   * NCSoft IDENTITY column → PG BIGSERIAL (id BIGINT). RETURNING id INTO
--     mirrors @@IDENTITY semantics (the NCSoft idiom returns -1 / 0 on
--     error; we return 0 in the EXCEPTION branch — same caller contract
--     as aion_PutPetNew2 which set the precedent).
--   * `deleted` is hard-coded to 0 in the INSERT — unchanged. Soft-delete
--     transitions through aion_DeleteFamiliar (00124) only.
--   * @createTime / @updateTime are caller-supplied epoch-millis; we do
--     NOT call NOW() here (unlike aion_PutPetNew2 which derives it from
--     GetUnixtimeWithUTCAdjust). NCSoft contract: caller owns the clock,
--     server is a dumb writer. Pinned.
--   * @name is NVARCHAR(50). PG TEXT accepts it; the user_familiar.name
--     column is TEXT NOT NULL DEFAULT '' (from 00115 scaffold). No length
--     CHECK in PG — caller pre-validates.
--   * @safetyFlag / @lootingState are TINYINT (0..255 in T-SQL but
--     practically 0/1 boolean-as-tinyint). PG side stores SMALLINT
--     (no TINYINT in PG; SMALLINT is the smallest int family).
--
-- Bug-for-bug:
--   * NCSoft does not validate @baseNameId / @curNameId existence — any
--     int passes. Pinned: no FK reference to a name catalog table.
--   * Returns 0 on ANY exception (uniqueness violation, NOT NULL violation,
--     etc.) — the caller has no way to distinguish "DB down" from "name
--     too long". Pinned: bug-for-bug compat with NCSoft @@ERROR<>0 RETURN 0.
--
-- Used by:
--   scripts/handlers/cm_familiar_create.lua     -- new familiar adoption
--   scripts/lib/familiar.lua                    -- shared write helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfamiliar(TEXT, INTEGER, INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _name           : familiar display name (NVARCHAR(50) → TEXT)
-- _master_id      : owning char_id
-- _base_name_id   : initial / unevolved name template id
-- _cur_name_id    : current name template id (= base on adoption)
-- _evolve_cnt     : evolution stage counter
-- _create_time    : caller epoch-millis (NOT server clock — pinned)
-- _update_time    : caller epoch-millis at adoption
-- _safety_flag    : 0/1 — protected vs sacrifice-able
-- _growth_point   : XP / growth resource
-- _slot1.._slot6  : 6 inventory slots — item ids (0 == empty)
-- _looting_state  : 0=disabled, 1=enabled (auto-loot toggle)
CREATE OR REPLACE FUNCTION aion_putfamiliar(
    _name          TEXT,
    _master_id     INTEGER,
    _base_name_id  INTEGER,
    _cur_name_id   INTEGER,
    _evolve_cnt    INTEGER,
    _create_time   BIGINT,
    _update_time   BIGINT,
    _safety_flag   SMALLINT,
    _growth_point  INTEGER,
    _slot1         INTEGER,
    _slot2         INTEGER,
    _slot3         INTEGER,
    _slot4         INTEGER,
    _slot5         INTEGER,
    _slot6         INTEGER,
    _looting_state SMALLINT
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    new_id BIGINT;
BEGIN
    INSERT INTO user_familiar
           (char_id, base_name_id, cur_name_id, name, evolve_cnt,
            create_time, update_time, safety_flag, growth_point,
            slot1, slot2, slot3, slot4, slot5, slot6,
            looting_state, deleted)
    VALUES (_master_id, _base_name_id, _cur_name_id, _name, _evolve_cnt,
            _create_time, _update_time, _safety_flag, _growth_point,
            _slot1, _slot2, _slot3, _slot4, _slot5, _slot6,
            _looting_state, 0)
    RETURNING id INTO new_id;
    RETURN new_id;
EXCEPTION WHEN others THEN
    -- Mirrors NCSoft `IF @@ERROR<>0 RETURN 0` — caller treats 0 as failure.
    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfamiliar(TEXT, INTEGER, INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
