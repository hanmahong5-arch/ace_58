-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserSkillSkinDA_Add.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userskillskinda_add(_char_id INTEGER, _skill_skin_id INTEGER, _expire_time INTEGER, _use_skin INTEGER, _update_time TIMESTAMPTZ)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT	user_skill_skin (char_id, skill_skin_id, expire_time, use_skin, update_time)

	VALUES	(_char_id, _skill_skin_id, _expire_time, _use_skin, _update_time);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userskillskinda_add;
-- +goose StatementEnd
