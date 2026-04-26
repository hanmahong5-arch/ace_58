-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMoveServiceLogDA_SrchNameChangeLogByOldName.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermoveservicelogda_srchnamechangelogbyoldname(_old_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



	select	l.id, l.char_id, l.old_name, l.new_name, l.change_date, l.item_id, l.tid, l.account_id, l.account_name, l.race, l.class, l.gender, l.lev

			, u.delete_complete_date, u.delete_date, u.org_server

	from	user_name_change_log l (nolock)

	left join user_data u (nolock) on u.char_id = l.char_id

	where	old_name = _old_name;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermoveservicelogda_srchnamechangelogbyoldname;
-- +goose StatementEnd
