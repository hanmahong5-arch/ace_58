-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AionTVContentsDA_Delete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_aiontvcontentsda_delete(_id INTEGER, _server_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	UPDATE	aion_tv_contents

	SET		is_deleted = 1

	WHERE	id = _id AND server_id = _server_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_aiontvcontentsda_delete;
-- +goose StatementEnd
