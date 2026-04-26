-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserTitleDA_SrchMytitlesByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usertitleda_srchmytitlesbycharid(_char_id TEXT, _is_have TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	title_id, expired_time

			from	user_title(nolock)

			where	char_id = _char_id and is_have=_is_have 

			order by title_id asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usertitleda_srchmytitlesbycharid;
-- +goose StatementEnd
