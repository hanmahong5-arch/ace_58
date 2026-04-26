-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AionTVContentsDA_DeleteAllAndInsert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_aiontvcontentsda_deleteallandinsert(_id INTEGER, _server_id INTEGER, _url TEXT, _start_date BIGINT, _end_date BIGINT, _login_id TEXT, _login_nm TEXT, _is_deleted INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	

	UPDATE	aion_tv_contents

	SET		is_deleted = 1

	WHERE	server_id = _server_id AND is_deleted != 1

	

	INSERT INTO aion_tv_contents (id, url, start_date, end_date, server_id, login_id, login_nm, reg_date, is_deleted)

	VALUES (_id, _url, _start_date, _end_date, _server_id, _login_id, _login_nm, NOW(), _is_deleted)

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_aiontvcontentsda_deleteallandinsert;
-- +goose StatementEnd
