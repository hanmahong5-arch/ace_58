-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetTodayMessage.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settodaymessage(_char_id INTEGER, _message TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data SET daily_comment = _message WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settodaymessage;
-- +goose StatementEnd
