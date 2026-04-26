-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCustomizeHistoryDA_SrchMyCustomizeHistory.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercustomizehistoryda_srchmycustomizehistory(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	* 

			from	user_customize_history (nolock) 

			where	char_id=_char_id 

			order by history_date asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercustomizehistoryda_srchmycustomizehistory;
-- +goose StatementEnd
