-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCreativityDA_SrchMyUseCreativityByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercreativityda_srchmyusecreativitybycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			



			SELECT category

				  ,enchant_object_id

				  ,value

				  ,accumulated_cp

				  ,data_id

			  FROM user_use_cp with(nolock)

			  where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercreativityda_srchmyusecreativitybycharid;
-- +goose StatementEnd
