-- AionCore 5.8 — Sprint 1.1a batch 4 port: aion_CommentDelete + user_comment table.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_CommentDelete.sql
-- Original (T-SQL):
--   IF @delete = 1  UPDATE user_comment SET deleted = 1 WHERE comment_id = @comment_id
--   ELSE IF @delete = 2  UPDATE user_comment SET deleted = 0 WHERE comment_id = @comment_id
--
-- Translation notes:
--   * The `@delete` parameter is a tri-state flag: 1 = soft-delete,
--     2 = restore (un-delete), anything else = no-op. We preserve the exact
--     branching semantics so existing callers (NCSoft GM tools, web admin)
--     do not need to be retrained — the SP is the boundary contract.
--   * `user_comment` is created here (first SP in the comment chain to
--     reach a fresh DB) — same scaffold-on-first-use pattern as the buddy
--     table in 00144. Co-batch 00157 (List) and 00158 (Write) re-declare
--     IF NOT EXISTS so partial / re-runs stay safe.
--   * `comment_id` is BIGSERIAL because aion_CommentWrite (00158) returns
--     `@@IDENTITY` after the INSERT — we mirror that with PG's RETURNING
--     and a serial primary key, which is the natural PG idiom.
--   * Returns rows-affected so callers can detect mismatched comment_ids
--     (parity with the rest of the bucket — 00144 / 00155).
--
-- Used by:
--   scripts/handlers/cm_comment_delete.lua  -- moderator / GM action
--   scripts/lib/comment.lua                 -- shared comment writer

-- +goose Up
-- +goose StatementBegin
-- comment_date defaults to NOW() so aion_CommentWrite (00158) doesn't have
-- to spell it out — and so the "writer is GM" insertion path used by
-- legacy admin scripts still gets a timestamp.
CREATE TABLE IF NOT EXISTS user_comment (
    comment_id    BIGSERIAL PRIMARY KEY,
    user_id       TEXT      NOT NULL DEFAULT '',
    char_id       INTEGER   NOT NULL,
    comment       TEXT      NOT NULL DEFAULT '',
    writer        TEXT      NOT NULL DEFAULT '',
    comment_date  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted       SMALLINT  NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_comment_char ON user_comment(char_id) WHERE deleted = 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentdelete(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentdelete(
    _delete     INTEGER,
    _comment_id BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER := 0;
BEGIN
    IF _delete = 1 THEN
        UPDATE user_comment SET deleted = 1 WHERE comment_id = _comment_id;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    ELSIF _delete = 2 THEN
        UPDATE user_comment SET deleted = 0 WHERE comment_id = _comment_id;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    END IF;
    -- All other _delete values are silently no-ops (matches T-SQL semantics).
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentdelete(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_comment_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_comment;
-- +goose StatementEnd
