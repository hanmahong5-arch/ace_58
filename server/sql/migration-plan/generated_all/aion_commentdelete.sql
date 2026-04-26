-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CommentDelete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentdelete(_delete INTEGER, _comment_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if _delete = 1

	update user_comment set deleted = 1 where comment_id = _comment_id

else if _delete = 2

	update user_comment set deleted = 0 where comment_id = _comment_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentdelete;
-- +goose StatementEnd
