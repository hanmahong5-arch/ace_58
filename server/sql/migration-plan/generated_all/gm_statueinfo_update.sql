-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_StatueInfo_Update.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_statueinfo_update(_npc_name_id INTEGER, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	UPDATE	statue_info

	SET		char_id = _char_id

	WHERE	npc_name_id = _npc_name_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_statueinfo_update;
-- +goose StatementEnd
