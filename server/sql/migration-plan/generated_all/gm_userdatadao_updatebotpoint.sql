-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateBotPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updatebotpoint(_char_id INTEGER, _bot_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_data

	    SET		bot_point = _bot_point

	    WHERE	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updatebotpoint;
-- +goose StatementEnd
