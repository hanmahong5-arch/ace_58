-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildOfflineChangeFlag.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildofflinechangeflag(_char_i_d INTEGER, _guild_offline_change_flag INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
IF _guild_offline_change_flag = 0

BEGIN

	UPDATE user_data

	SET guild_offline_change_flag=0,

		change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	WHERE char_id=_char_i_d

END

ELSE

BEGIN

	UPDATE user_data

	SET guild_offline_change_flag |= _guild_offline_change_flag,

		change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	WHERE char_id=_char_i_d

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildofflinechangeflag;
-- +goose StatementEnd
