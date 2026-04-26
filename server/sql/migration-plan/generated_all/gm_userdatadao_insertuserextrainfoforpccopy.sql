-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_InsertUserExtraInfoForPCCOPY.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_insertuserextrainfoforpccopy(_char_id INTEGER, _use_bot_channel INTEGER, _use_bot_channel_update_date TIMESTAMPTZ, _account_id INTEGER, _vip_icon INTEGER, _prev_season_reward INTEGER, _current_season_reward INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	INSERT INTO user_extra_info (char_id, use_bot_channel, use_bot_channel_update_date, account_id, vip_icon, prevSeasonReward, currentSeasonReward)

	VALUES (_char_id, _use_bot_channel, _use_bot_channel_update_date, _account_id, _vip_icon, _prev_season_reward, _current_season_reward)

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_insertuserextrainfoforpccopy;
-- +goose StatementEnd
