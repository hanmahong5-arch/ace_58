-- AionCore 5.8 — Sprint 1.1a batch 26 port: aion_DeleteSpawnAreaRank
-- (delete a single (world_no, spawn_area_name) row from spawn_area_rank).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteSpawnAreaRank.sql
-- Original (T-SQL):
--   SET NOCOUNT ON
--     delete spawn_area_rank where world_no=@world_no
--                              and spawn_area_name=@spawn_area_name
--   SET NOCOUNT OFF
--
-- Schema:
--   `spawn_area_rank` was introduced by 00266 (sister GetSpawnAreaRankList).
--
-- Translation notes:
--   * Single-row delete keyed on (world_no, spawn_area_name) — the same
--     tuple the writer (00267) uses as the upsert key.
--   * NCSoft `SET NOCOUNT ON/OFF` is a SQL Server statement-counter switch
--     that has no PG analogue; we drop it (the row-count signalling is
--     handled by `GET DIAGNOSTICS` instead).
--   * Returns INTEGER row-count (strict widening of NCSoft's VOID
--     contract — matches the convention in 00251 DeletePvPEnv and
--     00247 RemoveAllBlock). Lua callers may ignore the return.
--
-- Bug-for-bug:
--   * No matching row → returns 0, no error. Pinned.
--   * Multiple rows would only exist via direct INSERT bypassing the
--     upsert SP; in that case all matching rows are deleted (PK
--     prevents this in our schema, but if someone drops the PK in the
--     future, semantics still match NCSoft).
--   * spawn_area_name case-sensitivity divergence is documented on the
--     writer (00267); same caller-side normalisation policy applies here.
--
-- Used by:
--   scripts/handlers/gm_spawn_rank_remove.lua  -- GM "remove spawn area rank"
--   scripts/lib/spawn_area.lua                  -- shared deleter

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletespawnarearank(INTEGER, VARCHAR);
-- +goose StatementEnd

-- +goose StatementBegin
-- _world_no        : world (zone) id
-- _spawn_area_name : spawn area name (NCSoft nvarchar(40))
-- Returns rows-affected (0 or 1 in normalised data).
CREATE OR REPLACE FUNCTION aion_deletespawnarearank(
    _world_no        INTEGER,
    _spawn_area_name VARCHAR(40)
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    DELETE FROM spawn_area_rank
     WHERE world_no = _world_no
       AND spawn_area_name = _spawn_area_name;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletespawnarearank(INTEGER, VARCHAR);
-- +goose StatementEnd
