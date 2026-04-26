-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserInstance_SrchUserInsanceList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userinstance_srchuserinsancelist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED




	SELECT	id, char_id, world_id, instance_id, reentrance_time, server_id, count_variate, kina_increase, item_increase

	FROM	user_instance (nolock)

	WHERE	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userinstance_srchuserinsancelist;
-- +goose StatementEnd
