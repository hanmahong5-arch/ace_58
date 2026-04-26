-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserTitleDAO_AddorUpdate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usertitledao_addorupdate(_char_id TEXT, _title_id TEXT, _is_have TEXT, _expired_time TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT char_id FROM user_title (updlock) WHERE char_id=_char_id and title_id=_title_id ) 

		begin

			UPDATE user_title

			SET is_have = _is_have , expired_time = _expired_time

			WHERE char_id=_char_id and title_id=_title_id 

		end

		else

		begin

			INSERT into user_title(char_id, title_id, is_have, expired_time)

			VALUES (_char_id, _title_id, _is_have, _expired_time)

		end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usertitledao_addorupdate;
-- +goose StatementEnd
