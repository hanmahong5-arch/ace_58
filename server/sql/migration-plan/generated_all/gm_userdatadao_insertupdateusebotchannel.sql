-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_InsertUpdateUseBotChannel.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_insertupdateusebotchannel(_char_id INTEGER, _use_bot_channel INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_extra_info 

			SET		use_bot_channel = _use_bot_channel, 

					use_bot_channel_update_date = NOW()

			WHERE	char_id = _char_id

			IF (@_r_o_w_c_o_u_n_t < 1)

			BEGIN

				DECLARE	_account_id int

				SELECT account_id INTO _account_id FROM user_data WHERE char_id = _char_id



				INSERT INTO user_extra_info (char_id, use_bot_channel, use_bot_channel_update_date, account_id) 

				VALUES (_char_id, _use_bot_channel, NOW(), _account_id)

			END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_insertupdateusebotchannel;
-- +goose StatementEnd
