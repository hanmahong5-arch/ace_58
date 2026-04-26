-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_StatueInfo_Delete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_statueinfo_delete(_npc_name_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	DELETE FROM statue_info

	WHERE	npc_name_id = _npc_name_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_statueinfo_delete;
-- +goose StatementEnd
