-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetChatAccusedInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getchataccusedinfo(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	select accused_count, accused_count_penalty, penalty_start_time, last_accused_time FROM  user_chat_accused(updlock) where char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getchataccusedinfo;
-- +goose StatementEnd
