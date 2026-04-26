-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserChangeLogDA_SrchAllByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userchangelogda_srchallbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	convert(nvarchar, change_time,20) change_time, char_id, change_type, race, class, lev, old_value, new_value, playtime, intervaltime 

			from	user_change_log (nolock) 

			where	char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userchangelogda_srchallbycharid;
-- +goose StatementEnd
