-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharInGameBlockPunishInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharingameblockpunishinfo(_char_i_d INTEGER, _punish_code INTEGER, _remain_minute INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if  (_remain_minute <= 0)

begin

	update  User_Punishment 

	set Remain_Minute=_remain_minute,

		cancel_date = NOW(),

		cancel_reason = 'Apply_All_Penalty', 

		status = 1		

	where char_id=_char_i_d and status = 0 and punish_code = _punish_code

end

else

begin

	update  User_Punishment 

	set Remain_Minute=_remain_minute

	where char_id=_char_i_d and status = 0 and punish_code = _punish_code

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharingameblockpunishinfo;
-- +goose StatementEnd
