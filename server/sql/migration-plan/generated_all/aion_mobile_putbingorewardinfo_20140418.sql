-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_Mobile_PutBingoRewardInfo_20140418.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mobile_putbingorewardinfo_20140418(_account_id INTEGER, _char_id INTEGER, _board_id INTEGER, _reward_pack_id INTEGER, _amount BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	INSERT INTO	user_bingo_reward 

	(char_id, board_id,	reward_pack_id, reward_date, account_id, amount) 

	VALUES (_char_id, _board_id, _reward_pack_id, NOW(), _account_id, _amount)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mobile_putbingorewardinfo_20140418;
-- +goose StatementEnd
