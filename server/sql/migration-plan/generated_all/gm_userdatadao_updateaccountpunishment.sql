-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateAccountPunishment.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updateaccountpunishment(_account_id INTEGER, _account_punishment INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	UPDATE	user_data

	SET		account_punishment = _account_punishment

	WHERE	account_id = _account_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updateaccountpunishment;
-- +goose StatementEnd
