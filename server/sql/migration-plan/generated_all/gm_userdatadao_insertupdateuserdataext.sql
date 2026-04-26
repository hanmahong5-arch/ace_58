-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_InsertUpdateUserDataExt.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_insertupdateuserdataext(_char_id INTEGER, _exps_login_reward_time INTEGER, _exps_npckill_reward_num INTEGER, _creativity_point INTEGER, _usecp_resetcount INTEGER, _next_usecp_resetcount_dec_time BIGINT, _familiar_func_expire_time BIGINT, _familiar_energy INTEGER, _familiar_energy_autocharge INTEGER, _familiar_func_autocharge INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_data_ext

	SET		exps_login_reward_time = _exps_login_reward_time

			, exps_npckill_reward_num = _exps_npckill_reward_num

			, creativity_point = _creativity_point

			, usecp_resetcount = _usecp_resetcount

			, next_usecp_resetcount_dec_time = _next_usecp_resetcount_dec_time

			, familiar_func_expireTime = _familiar_func_expire_time

			, familiar_energy = _familiar_energy

			, familiar_energy_autocharge = _familiar_energy_autocharge

			, familiar_func_autocharge = _familiar_func_autocharge

	WHERE	char_id = _char_id



	IF (@_r_o_w_c_o_u_n_t < 1)

	BEGIN

		INSERT INTO user_data_ext (char_id, exps_login_reward_time, exps_npckill_reward_num, creativity_point, usecp_resetcount, next_usecp_resetcount_dec_time, familiar_func_expireTime, familiar_energy, familiar_energy_autocharge, familiar_func_autocharge)

		VALUES (_char_id, _exps_login_reward_time, _exps_npckill_reward_num, _creativity_point, _usecp_resetcount, _next_usecp_resetcount_dec_time, _familiar_func_expire_time, _familiar_energy, _familiar_energy_autocharge, _familiar_func_autocharge)

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_insertupdateuserdataext;
-- +goose StatementEnd
