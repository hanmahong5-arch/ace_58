-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_InsertUpdateGPAdd.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_insertupdategpadd(_char_id INTEGER, _glory_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			IF EXISTS (SELECT char_id FROM user_gp_data WHERE char_id=_char_id)

			BEGIN

				UPDATE user_gp_data SET glory_point = glory_point + _glory_point WHERE char_id=_char_id

			END

			ELSE

			BEGIN

				INSERT INTO user_gp_data (char_id, glory_point) VALUES (_char_id, _glory_point)

				--  DEFAULT:ownership_bonus_gp

			END

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_insertupdategpadd;
-- +goose StatementEnd
