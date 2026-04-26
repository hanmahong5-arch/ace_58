-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserChangeLogDA_SrchByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userchangelogda_srchbycharid(_char_id INTEGER, _change_type TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	* 

			from	user_change_log(nolock) 

			where	char_id=_char_id and change_type=''+_change_type+''

			order by change_time desc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userchangelogda_srchbycharid;
-- +goose StatementEnd
