-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetSkillSkin.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setskillskin(_char_id INTEGER, _skill_skin_id INTEGER, _command_type INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF _command_type = 3	-- USE		//장착

	BEGIN

		UPDATE user_skill_skin SET use_skin = 1 WHERE char_id = _char_id AND skill_skin_id = _skill_skin_id

	END



	IF _command_type = 4	-- DIUSE		//해제

	BEGIN

		UPDATE user_skill_skin SET use_skin = 0 WHERE char_id = _char_id AND skill_skin_id = _skill_skin_id

	END



	IF _command_type = 5	-- EXPIRE	//만료

	BEGIN

		UPDATE user_skill_skin SET use_skin = 0, expire_time = 0 WHERE char_id = _char_id AND skill_skin_id = _skill_skin_id

	END




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setskillskin;
-- +goose StatementEnd
