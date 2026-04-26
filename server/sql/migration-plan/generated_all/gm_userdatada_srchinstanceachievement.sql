-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchInstanceAchievement.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchinstanceachievement(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	world_id, spawn_page, version, data

	FROM	user_instance_achievement (nolock)

	WHERE	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchinstanceachievement;
-- +goose StatementEnd
