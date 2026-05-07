-- AionCore 5.8 — Sprint 1.1a batch 16 port: aion_GetEnslaveStone (enslave-stone SELECT-by-id).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetEnslaveStone.sql
-- Original (T-SQL):
--   SELECT status, monsterClass, lev, exp
--   FROM user_item_enslave_stone
--   WHERE id=@id
--
-- Schema delta:
--   First port to touch user_item_enslave_stone — table does not yet exist
--   in PG. Create with NCSoft's column names preserved verbatim
--   (status / monsterClass / lev / exp). monsterClass is mixedCase in the
--   original schema so we double-quote it; the others are plain lowercase.
--   id is the user_item.id surrogate key (BIGINT in NCSoft) — pin BIGINT so
--   future joins to user_item (also BIGSERIAL) are type-compatible.
--
-- Translation notes:
--   * NCSoft column types (verified against schema dump):
--       id           BIGINT  (PK; matches user_item.id)
--       status       INT     (0=unsealed-but-blank, 1=bound, 2=consumed,
--                             3=stored, etc — see client EnslaveStone enum)
--       monsterClass INT     (0 until first capture; references monster_id)
--       lev          INT     (level of captured monster, 0 default)
--       exp          BIGINT  (cumulative exp, 0 default — wide enough for
--                             prolonged use; NCSoft used INT but the 5.0+
--                             enslave grind can legitimately exceed INT_MAX)
--   * Single-row SP — `WHERE id=@id` on PK; either zero or one row.
--   * No NOLOCK hint in T-SQL source. PG MVCC snapshot semantics suffice.
--   * STABLE marker — pure SELECT, no side effects.
--
-- Bug-for-bug:
--   * No char_id parameter or filter — returns row by id alone. The caller
--     (handler / Lua) is responsible for ownership checks. Same trust model
--     as item_seal Get (00212). Pinned verbatim.
--
-- Used by:
--   scripts/handlers/cm_enslave_stone_inspect.lua  (player inspects stone)
--   scripts/lib/enslave_stone.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_item_enslave_stone — first introduction of this table. Column
-- names preserved with NCSoft mixedCase (`monsterClass`). PG would fold
-- to lowercase without quoting; we quote in DDL and SELECT alike.
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_item_enslave_stone (
    id              BIGINT PRIMARY KEY,
    status          INTEGER NOT NULL DEFAULT 0,
    "monsterClass"  INTEGER NOT NULL DEFAULT 0,
    lev             INTEGER NOT NULL DEFAULT 0,
    exp             BIGINT  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getenslavestone(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getenslavestone(_id BIGINT)
RETURNS TABLE (
    status          INTEGER,
    "monsterClass"  INTEGER,
    lev             INTEGER,
    exp             BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT s.status, s."monsterClass", s.lev, s.exp
          FROM user_item_enslave_stone s
         WHERE s.id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getenslavestone(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_item_enslave_stone;
-- +goose StatementEnd
