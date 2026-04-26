-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserSkillSkinDA_Delete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userskillskinda_delete(_char_id INTEGER, _skill_skin_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_skill_skin WHERE char_id = _char_id and skill_skin_id = _skill_skin_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userskillskinda_delete;
-- +goose StatementEnd
