-- AionCore 5.8 — Sprint 1.1a batch 19 port: aion_addErrorIgnore
-- (server-side dedup INSERT into error_ignore — client error suppression list).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_addErrorIgnore.sql
-- Original (T-SQL):
--   declare @count int
--   select @count = COUNT(*) from error_ignore where ignore = @ignore
--   if @count > 0
--       return
--   insert into error_ignore values(@ignore)
--
-- Translation notes:
--   * Conditional INSERT — caller-side dedup using SELECT-COUNT-then-INSERT.
--     Classic T-SQL race-condition trap (SELECT and INSERT not atomic);
--     we pin the bug for compatibility but PG idiom would be UNIQUE +
--     ON CONFLICT DO NOTHING. Use ON CONFLICT here as the structural
--     equivalent — preserves NCSoft's "no duplicate, no error on dup"
--     contract while being concurrency-safe (T-SQL would silently dup
--     on race; PG ON CONFLICT prevents that, slight semantic upgrade
--     called out here).
--   * `error_ignore` table is **first introduced here**. NCSoft schema:
--       id      INT IDENTITY (PK, surrogate)
--       ignore  NVARCHAR(256) (the suppressed error key — typically a
--                              client-side error code or substring)
--   * Parameter widths verified:
--       @ignore  NVARCHAR(256) → VARCHAR(256) (UTF-8; PG NVARCHAR alias)
--   * VOLATILE — data-modifying.
--   * Returns rows-affected (0 on dup, 1 on fresh). Caller can detect
--     "already known" without a separate query — slight enhancement over
--     T-SQL's silent return; pinned safe because no caller branches on
--     the count today (Lua treats both as success).
--
-- Bug-for-bug:
--   * Case-sensitive match. NCSoft default collation on the column is
--     case-insensitive (Latin1_General_CI_AS) but PG default is binary.
--     PINNED choice: keep PG case-sensitive (binary) — error keys are
--     typically machine-generated codes, not human labels, so CS is the
--     safer truth. Documented gap with original T-SQL CI behaviour.
--   * No length CHECK; over-256 inputs would be silently truncated in
--     T-SQL (NVARCHAR(256)) but PG raises on overflow. Caller must
--     pre-validate. Pinned — defensive stance.
--   * No FK to anywhere; standalone moderation list.
--
-- Used by:
--   scripts/handlers/cm_client_error_report.lua  (suppress repeated errors)
--   scripts/lib/error_ignore.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- error_ignore — first introduction. Client-side error suppression
-- list. id surrogate + dedup-on-text-key (UNIQUE for upsert safety).
-- ====================================================================
CREATE TABLE IF NOT EXISTS error_ignore (
    id      BIGSERIAL    PRIMARY KEY,
    ignore  VARCHAR(256) NOT NULL UNIQUE
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_adderrorignore(VARCHAR);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_adderrorignore(
    _ignore VARCHAR(256)
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- T-SQL "SELECT-COUNT-then-INSERT" → PG ON CONFLICT DO NOTHING.
    -- Semantic upgrade: race-safe vs original (NCSoft can dup on race).
    INSERT INTO error_ignore (ignore)
    VALUES (_ignore)
    ON CONFLICT (ignore) DO NOTHING;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_adderrorignore(VARCHAR);
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS error_ignore;
-- +goose StatementEnd
