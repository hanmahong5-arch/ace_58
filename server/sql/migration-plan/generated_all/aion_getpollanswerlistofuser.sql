-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetPollAnswerListOfUser.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpollanswerlistofuser(_account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select poll_id, char_id

from poll_answer with(nolock)

where account_id = _account_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpollanswerlistofuser;
-- +goose StatementEnd
