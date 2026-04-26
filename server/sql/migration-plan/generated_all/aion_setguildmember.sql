-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildMember.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildmember(_guild_id INTEGER, _char_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data 

	SET guild_id = _guild_id,guild_update_date = NOW(), 

		change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	WHERE char_id = _char_id

	

	DECLARE _ret int



	SELECT guild_id INTO _ret FROM user_data WHERE char_id = _char_id



	RETURN _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildmember;
-- +goose StatementEnd
