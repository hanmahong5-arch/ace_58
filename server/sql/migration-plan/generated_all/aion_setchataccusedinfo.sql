-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetChatAccusedInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchataccusedinfo(_char_id INTEGER, _accused_count INTEGER, _accused_count_penalty INTEGER, _penalty_start_time INTEGER, _last_accused_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT char_id from user_chat_accused(updlock) where char_id = _char_id

	if @_rowcount = 0 

		insert into user_chat_accused (char_id, accused_count, accused_count_penalty, penalty_start_time, last_accused_time) values (_char_id, _accused_count, _accused_count_penalty, _penalty_start_time, _last_accused_time)

	ELSE

		UPDATE user_chat_accused SET char_id = _char_id, accused_count = _accused_count, accused_count_penalty = _accused_count_penalty, penalty_start_time = _penalty_start_time, last_accused_time=_last_accused_time WHERE char_id = _char_id

END /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchataccusedinfo;
-- +goose StatementEnd
