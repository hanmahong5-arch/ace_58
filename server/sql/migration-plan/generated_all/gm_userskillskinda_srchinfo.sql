-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserSkillSkinDA_SrchInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userskillskinda_srchinfo(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT skill_skin_id, expire_time, use_skin, update_time

	FROM	user_skill_skin (nolock)

	WHERE	char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userskillskinda_srchinfo;
-- +goose StatementEnd
