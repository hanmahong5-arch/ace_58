-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_StatueInfo_Srch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_statueinfo_srch()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted


	

	SELECT	s.npc_name_id, s.char_id, 

			u.user_id, u.class, u.lev, u.delete_date, u.delete_complete_date, u.delete_type, u.org_server

	FROM	statue_info s (nolock)

	LEFT JOIN	user_data u (nolock) on u.char_id = s.char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_statueinfo_srch;
-- +goose StatementEnd
