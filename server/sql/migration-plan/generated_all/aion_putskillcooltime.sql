-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutSkillCooltime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskillcooltime(_char_id INTEGER, _cooltime_data_cnt INTEGER, _data BYTEA)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select char_id from user_skill_cooltime(UPDLOCK) where char_id = _char_id) 

	begin

		update user_skill_cooltime set cooltime_data_cnt = _cooltime_data_cnt, data = _data where char_id = _char_id

	end

else 

	begin

		insert user_skill_cooltime(char_id, cooltime_data_cnt, data) values (_char_id, _cooltime_data_cnt, _data)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillcooltime;
-- +goose StatementEnd
