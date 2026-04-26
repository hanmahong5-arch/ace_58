-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_StatueInfo_Insert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_statueinfo_insert(_npc_name_id INTEGER, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	INSERT INTO statue_info (npc_name_id, char_id)

	VALUES (_npc_name_id, _char_id)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_statueinfo_insert;
-- +goose StatementEnd
