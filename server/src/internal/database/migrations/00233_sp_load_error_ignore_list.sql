-- AionCore 5.8 — Sprint 1.1a batch 19 port: aion_LoadErrorIgnoreList
-- (full SELECT of error_ignore — boot-time hot-cache load).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_LoadErrorIgnoreList.sql
-- Original (T-SQL):
--   select id, ignore from error_ignore order by id
--
-- Translation notes:
--   * Pure SELECT-all, ordered by id ASC. Used at world-engine boot to
--     materialise the suppression list into a hot-path Lua set. Not on
--     any per-tick path — runs once per process start (and on hot-reload
--     of scripts/lib/error_ignore.lua).
--   * Returns 2 columns: (id BIGINT, ignore TEXT). RPC layer reads
--     positionally — Go scan order pinned.
--   * STABLE — pure read, no side effects.
--   * Set size in NCSoft live: ~hundreds of entries, well under 1k.
--     No pagination; full set fits in one round-trip.
--
-- Bug-for-bug:
--   * Returns ALL rows unconditionally — no filter, no limit. NCSoft
--     pin. Caller could OOM if the list grew unbounded; pinned because
--     server admins prune via direct SQL, not via SP.
--   * id ordering is stable (BIGSERIAL monotonic) but not cryptographic-
--     ally guaranteed; ties impossible due to UNIQUE + sequence. No
--     extra ORDER tiebreaker needed.
--   * No JOIN — `ignore` is a free-form key, the suppression list does
--     not annotate "who reported it" or "when". Pinned.
--
-- Used by:
--   scripts/lib/error_ignore.lua       (boot-time set load)
--   admin REST: GET /admin/error-ignore (GM dashboard, read-only)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loaderrorignorelist();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loaderrorignorelist()
RETURNS TABLE (
    id     BIGINT,
    ignore VARCHAR(256)
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- ORDER BY id ASC pinned per T-SQL contract.
    RETURN QUERY
    SELECT ei.id, ei.ignore
      FROM error_ignore ei
     ORDER BY ei.id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loaderrorignorelist();
-- +goose StatementEnd
