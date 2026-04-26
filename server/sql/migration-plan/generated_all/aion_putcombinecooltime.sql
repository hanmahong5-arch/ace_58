-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutCombineCoolTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcombinecooltime(_char_id INTEGER, _cooltime_id INTEGER, _expire_cooltime BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select char_id from user_combine_cooltime(UPDLOCK) where char_id = _char_id and cooltime_id = _cooltime_id) 

	begin

		update user_combine_cooltime

		set expire_cooltime = _expire_cooltime

		where char_id = _char_id and cooltime_id = _cooltime_id

	end

else 

	begin

		insert user_combine_cooltime(char_id, cooltime_id, expire_cooltime)

		values (_char_id, _cooltime_id, _expire_cooltime)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcombinecooltime;
-- +goose StatementEnd
