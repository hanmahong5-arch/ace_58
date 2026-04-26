-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutSkillSkin.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskillskin(_char_id INTEGER, _skill_skin_id INTEGER, _expire_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	if EXISTS (SELECT char_id FROM user_skill_skin (UPDLOCK) WHERE char_id = _char_id AND skill_skin_id = _skill_skin_id) 

		begin

			UPDATE user_skill_skin SET use_skin = 0, expire_time = _expire_time, update_time = NOW() WHERE char_id = _char_id AND skill_skin_id = _skill_skin_id

		end

	else 

		begin

			INSERT user_skill_skin(char_id, skill_skin_id, expire_time, use_skin) VALUES (_char_id, _skill_skin_id, _expire_time, 0)

		end




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillskin;
-- +goose StatementEnd
