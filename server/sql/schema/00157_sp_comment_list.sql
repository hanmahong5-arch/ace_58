-- AionCore 5.8 — Sprint 1.1a batch 4 port: aion_CommentList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_CommentList.sql
-- Original (T-SQL):
--   DECLARE @utc_adjust = dbo.GetUtcAdjustSecWithUTC_Local(GetUTCDate(), GetDate())
--   SELECT comment_id, comment, writer,
--          dbo.GetUnixtimeWithUTCAdjust(comment_date, @utc_adjust) AS comment_date
--     FROM user_comment WITH(NOLOCK)
--    WHERE char_id = @char_id AND deleted = 0
--    ORDER BY comment_id DESC
--
-- Translation notes:
--   * The original deliberately fights SQL Server's mismatch between
--     GetUTCDate() and GetDate() by computing a session-local UTC offset
--     and adjusting the stored DATETIME at read-time. PG sidesteps the
--     entire problem with TIMESTAMPTZ — every value is stored as UTC
--     plus a per-row timezone, and `extract(epoch from ts)::bigint`
--     trivially yields the unix-time the client expects, identical
--     to what the legacy client received from `GetUnixtimeWithUTCAdjust`.
--     Result: the SP returns the SAME 4 columns the original did, but
--     does not need the 30-line UTC-adjust dance.
--   * `WITH(NOLOCK)` is dropped (PG MVCC; see 00148 commentary).
--   * Function declared STABLE so callers joining against this in a
--     SELECT can be inlined by the planner.
--   * Bigint return for `comment_date`: the wire protocol field is
--     uint32 epoch-seconds today (5.8) but storing as bigint future-proofs
--     past 2038 without breaking the returned shape.
--   * Table is created idempotently because each SP in the comment chain
--     (00156/57/58) declares it — order-independent for fresh DBs.
--
-- Used by:
--   scripts/handlers/cm_comment_list.lua  -- player profile / web admin
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
DROP FUNCTION IF EXISTS aion_commentlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentlist(_char_id INTEGER)
RETURNS TABLE (
    comment_id    BIGINT,
    comment       TEXT,
    writer        TEXT,
    comment_date  BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uc.comment_id,
               uc.comment,
               uc.writer,
               EXTRACT(EPOCH FROM uc.comment_date)::BIGINT AS comment_date
          FROM user_comment uc
         WHERE uc.char_id = _char_id
           AND uc.deleted = 0
         ORDER BY uc.comment_id DESC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentlist(INTEGER);
-- +goose StatementEnd
