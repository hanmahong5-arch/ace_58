-- AionCore 5.8 — Sprint 1.1a batch 4 port: aion_CommentWrite.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_CommentWrite.sql
-- Original (T-SQL):
--   INSERT INTO user_comment(user_id, char_id, comment, writer)
--        VALUES (@user_id, @char_id, @comment, @writer)
--   IF @@ERROR <> 0 RETURN 0
--   RETURN @@IDENTITY
--
-- Translation notes:
--   * `@@IDENTITY` after an INSERT is the SQL Server idiom for "give me back
--     the auto-generated primary key". PG's idiomatic equivalent is
--     `INSERT ... RETURNING comment_id`. This SP follows the convention used
--     by aion_AddItemUser (00135) and aion_MailWrite (00133): RETURN the
--     newly-assigned comment_id directly so the caller can echo it to the
--     client (SM_COMMENT_WRITE_RESULT) without a round-trip SELECT.
--   * `@@ERROR <> 0 RETURN 0` is the original "0 means failure" contract.
--     PG converts any data-integrity error into an exception that bubbles
--     up to the Go layer, so we do NOT need a manual error-path return —
--     callers see a non-nil error from CallSPRow which is strictly more
--     informative than the magic 0.
--   * comment_date defaults to NOW() at the table level (declared in 00156)
--     so the INSERT does not need to spell it out — all three SP-chain
--     migrations re-declare the table IF NOT EXISTS for ordering safety.
--   * Length budget: NCSoft `comment` is nvarchar(200), `writer` nvarchar(32),
--     `user_id` nvarchar(20). PG TEXT has no defined upper bound; we keep
--     the columns wide-open because the wire-protocol enforces the cap on
--     ingest (CM_COMMENT_WRITE limits the bytes pushed) and going wider
--     here gives migration headroom for client patches without a schema
--     change.
--
-- Used by:
--   scripts/handlers/cm_comment_write.lua
--   scripts/lib/comment.lua

-- +goose Up
-- +goose StatementBegin
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
DROP FUNCTION IF EXISTS aion_commentwrite(TEXT, INTEGER, TEXT, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentwrite(
    _user_id  TEXT,
    _char_id  INTEGER,
    _comment  TEXT,
    _writer   TEXT
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    new_id BIGINT;
BEGIN
    INSERT INTO user_comment(user_id, char_id, comment, writer)
    VALUES (_user_id, _char_id, _comment, _writer)
    RETURNING comment_id INTO new_id;
    RETURN new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentwrite(TEXT, INTEGER, TEXT, TEXT);
-- +goose StatementEnd
