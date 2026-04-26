-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutCharInGameBlockPunishInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcharingameblockpunishinfo(_account_id INTEGER, _character_id INTEGER, _punish_code INTEGER, _remain_min INTEGER, _punish_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	UPDATE user_punishment SET status = 1, cancel_date = NOW() WHERE account_id = _account_id and char_id = _character_id and punish_code = _punish_code and status = 0

	

	INSERT INTO user_punishment(account_id, char_id, play_block, status, punish_code, start_date, end_date, remain_minute, punish_reason) 

	VALUES (_account_id, _character_id, 0, 0, _punish_code, NOW(), DATEADD(minute, _remain_min, NOW()), _remain_min, _punish_reason)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcharingameblockpunishinfo;
-- +goose StatementEnd
