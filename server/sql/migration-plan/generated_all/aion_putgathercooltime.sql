-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutGatherCoolTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putgathercooltime(_char_id INTEGER, _cooltime_id INTEGER, _expire_cooltime BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select char_id from user_gather_cooltime(UPDLOCK) where char_id = _char_id and cooltime_id = _cooltime_id) 

	begin

		update user_gather_cooltime

		set expire_cooltime = _expire_cooltime

		where char_id = _char_id and cooltime_id = _cooltime_id

	end

else 

	begin

		insert user_gather_cooltime(char_id, cooltime_id, expire_cooltime)

		values (_char_id, _cooltime_id, _expire_cooltime)

	end











/****** Object:  StoredProcedure aion_GetGatherCoolTimeList    Script Date: 09/15/2009 17:13:13 ******/

SET ANSI_NULLS OFF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putgathercooltime;
-- +goose StatementEnd
