-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPetitionWebNotify.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetitionwebnotify(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF NOT EXISTS (SELECT id FROM user_petition_web(updlock) WHERE char_id = _char_id)

		INSERT INTO user_petition_web(char_id) VALUES (_char_id)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionwebnotify;
-- +goose StatementEnd
