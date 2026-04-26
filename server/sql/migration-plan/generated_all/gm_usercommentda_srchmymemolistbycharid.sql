-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCommentDA_SrchMyMemoListByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercommentda_srchmymemolistbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	* 

			from	user_comment(nolock) 

			where	char_id=_char_id 

			order by comment_id desc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercommentda_srchmymemolistbycharid;
-- +goose StatementEnd
