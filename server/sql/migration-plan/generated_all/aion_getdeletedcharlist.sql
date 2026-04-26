-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDeletedCharList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdeletedcharlist(_server_id INTEGER, _cur_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    SELECT char_id, user_id, account_id, account_name, guild_id, guild_rank 

	FROM user_data with(nolock, index=IX_delete_complete_date)

	WHERE delete_complete_date = 0 and delete_date > 0 and delete_date <= _cur_time


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdeletedcharlist;
-- +goose StatementEnd
