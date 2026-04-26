-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharEXPS_RewardNum.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharexps_rewardnum(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 




	UPDATE user_data_ext SET exps_npckill_reward_num = exps_npckill_reward_num + 1 where char_id = _char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharexps_rewardnum;
-- +goose StatementEnd
