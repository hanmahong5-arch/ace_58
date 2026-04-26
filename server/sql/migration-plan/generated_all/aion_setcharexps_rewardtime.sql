-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharEXPS_RewardTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharexps_rewardtime(_char_id INTEGER, _reward_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 




	IF not exists (select char_id from user_data_ext(updlock) where char_id = _char_id)

		insert into user_data_ext (char_id, exps_login_reward_time, exps_npckill_reward_num) values(_char_id, _reward_time, 0)

	ELSE

		UPDATE user_data_ext SET exps_login_reward_time = _reward_time, exps_npckill_reward_num = 0 where char_id = _char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardtime;
-- +goose StatementEnd
