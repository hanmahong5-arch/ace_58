-- AionCore 5.8 — Sprint 1.1a batch 16 port: aion_PutEnslaveStone (enslave-stone INSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutEnslaveStone.sql
-- Original (T-SQL):
--   INSERT user_item_enslave_stone(id, status, monsterClass, lev, exp)
--   VALUES (@id, 0, 0, 0, 0)
--
-- Translation notes:
--   * Sister of 00214 GetEnslaveStone. Bootstraps a brand-new enslave stone
--     row with all four mutable columns at default 0. The table is created
--     in 00214; this migration only adds the function.
--   * Single param @id BIGINT — the user_item.id surrogate. Caller (handler)
--     allocates the user_item row first, then calls Put to seed the
--     enslave_stone child record.
--   * No upsert semantics in T-SQL — pure INSERT. If id already exists,
--     T-SQL raises 2627 (PK violation). NCSoft callers always check
--     existence (Get returning 0 rows) before calling Put, so the collision
--     case is unreachable in production. We pin verbatim: PG raises
--     SQLSTATE 23505 on duplicate, surfaced as a pgconn.PgError to the Go
--     caller. Lua callers see this as a fatal SP error.
--   * VOID return — INSERT … no OUTPUT clause; row count is implicit (1).
--     Mirror via PG plpgsql with no RETURNS payload.
--
-- Bug-for-bug:
--   * Only id is parameterised — initial (status, monsterClass, lev, exp)
--     are HARD-CODED to 0. Even if a caller passes a captured monsterClass
--     they cannot seed it on insert; they MUST follow with a separate
--     UPDATE / Set SP. NCSoft's design — pinned verbatim, do NOT widen the
--     signature to accept the four columns.
--   * No char_id link — same orphan-tolerance as item_seal. The
--     enslave_stone row is identified solely by item id; ownership
--     enforced via the parent user_item row.
--
-- Used by:
--   scripts/handlers/cm_use_item.lua  (when consuming an EnslaveStoneSeed)
--   scripts/lib/enslave_stone.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putenslavestone(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putenslavestone(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Hard-coded zero defaults — NCSoft contract pinned. Do NOT add
    -- ON CONFLICT — duplicates must surface as errors so the caller can
    -- distinguish "fresh stone" vs "already seeded".
    INSERT INTO user_item_enslave_stone (id, status, "monsterClass", lev, exp)
    VALUES (_id, 0, 0, 0, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putenslavestone(BIGINT);
-- +goose StatementEnd
