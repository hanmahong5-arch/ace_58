-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserTitleDA_SrchMyAlltitlesByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usertitleda_srchmyalltitlesbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted			

			

			select	char_id, title_id, is_have, expired_time

			from	user_title(nolock)

			where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usertitleda_srchmyalltitlesbycharid;
-- +goose StatementEnd
