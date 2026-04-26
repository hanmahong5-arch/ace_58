-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AionTVContentsDA_InsertUpdate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_aiontvcontentsda_insertupdate(_id INTEGER, _server_id INTEGER, _url TEXT, _start_date BIGINT, _end_date BIGINT, _login_id TEXT, _login_nm TEXT, _is_deleted INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	UPDATE	aion_tv_contents

	SET		url = _url

			, start_date = _start_date

			, end_date = _end_date

			, login_id = _login_id

			, login_nm = _login_nm

			, is_deleted = _is_deleted

			, reg_date = NOW()

	WHERE	id = _id AND server_id = _server_id

	IF (@_r_o_w_c_o_u_n_t < 1)

	BEGIN

		INSERT INTO aion_tv_contents (id, url, start_date, end_date, server_id, login_id, login_nm, reg_date, is_deleted)

		VALUES (_id, _url, _start_date, _end_date, _server_id, _login_id, _login_nm, NOW(), _is_deleted)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_aiontvcontentsda_insertupdate;
-- +goose StatementEnd
