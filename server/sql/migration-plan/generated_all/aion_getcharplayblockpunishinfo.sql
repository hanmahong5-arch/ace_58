-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharPlayBlockPunishInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharplayblockpunishinfo(_char_i_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare	_utc_adjust_hour bigint

	_utc_adjust_hour := DATEDIFF(HH, (NOW() AT TIME ZONE 'UTC'), NOW())



	SELECT punish_code,

			DATEDIFF(SS, DATEADD(HH, _utc_adjust_hour, '1970-01-01'), start_date) as start_date,

			DATEDIFF(SS, DATEADD(HH, _utc_adjust_hour, '1970-01-01'), end_date) as end_date,

			punish_reason 

	FROM user_punishment

	WHERE	char_id = _char_i_d and play_block = 1 and status = 0 and end_date > NOW();
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharplayblockpunishinfo;
-- +goose StatementEnd
