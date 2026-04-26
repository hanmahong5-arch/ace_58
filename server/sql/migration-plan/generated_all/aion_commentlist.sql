-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CommentList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _utc_adjust bigint

_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())



select comment_id, comment, writer, GetUnixtimeWithUTCAdjust(comment_date, _utc_adjust) as comment_date from user_comment (nolock) 

where char_id = _char_id and deleted = 0

order by comment_id desc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentlist;
-- +goose StatementEnd
