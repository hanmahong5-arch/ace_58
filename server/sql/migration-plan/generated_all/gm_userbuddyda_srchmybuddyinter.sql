-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserBuddyDA_SrchMyBuddyInter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userbuddyda_srchmybuddyinter(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	set ansi_warnings off



	select	char_id, buddy_id, delete_flag, buddy_name, server_id, COALESCE(comment, '') as comment

	from	user_buddy_inter

	where	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userbuddyda_srchmybuddyinter;
-- +goose StatementEnd
