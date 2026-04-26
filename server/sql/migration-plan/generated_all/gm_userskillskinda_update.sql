-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserSkillSkinDA_Update.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userskillskinda_update(_char_id INTEGER, _skill_skin_id INTEGER, _expire_time INTEGER, _use_skin INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_skill_skin

	SET

		expire_time = COALESCE(_expire_time, expire_time),

		use_skin = COALESCE(_use_skin, use_skin)

	WHERE	char_id = _char_id AND skill_skin_id = _skill_skin_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userskillskinda_update;
-- +goose StatementEnd
