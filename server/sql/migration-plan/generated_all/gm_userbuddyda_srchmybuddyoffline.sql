-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserBuddyDA_SrchMyBuddyOffline.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userbuddyda_srchmybuddyoffline(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	set ansi_warnings off



	select	user_id, inviter_id, inviter_name, inviter_msg, createdate, userlevel, userclass, gender

	from	user_buddy_offline

	where	user_id = _user_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userbuddyda_srchmybuddyoffline;
-- +goose StatementEnd
