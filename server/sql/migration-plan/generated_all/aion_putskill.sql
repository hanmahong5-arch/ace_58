-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutSkill.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskill(_char_id INTEGER, _skill_id INTEGER, _skill_data1 INTEGER, _skill_data2 INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION


if EXISTS (SELECT skill_id FROM user_skill(UPDLOCK) WHERE  char_id=_char_id and skill_id=_skill_id) 

begin

	UPDATE user_skill

	SET skill_data1 = _skill_data1 , skill_data2 = _skill_data2 

	WHERE char_id=_char_id and skill_id=_skill_id 

end

else

begin

	INSERT user_skill(char_id, skill_id, skill_data1, skill_data2) 

	VALUES (_char_id, _skill_id, _skill_data1,_skill_data2)	

end


COMMIT TRANSACTION;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskill;
-- +goose StatementEnd
