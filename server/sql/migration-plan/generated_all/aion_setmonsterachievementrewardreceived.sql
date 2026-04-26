-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetMonsterAchievementRewardReceived.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmonsterachievementrewardreceived(_grade_of_reward INTEGER, _char_id INTEGER, _achieve_id INTEGER, _reward_received INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
_grade_of_reward := -1



	UPDATE	user_monster_achievement

	SET		reward_received = _reward_received, _grade_of_reward = _reward_received

	WHERE	char_id = _char_id AND achieve_id = _achieve_id AND reward_received = _reward_received - 1

	

	return @_r_o_w_c_o_u_n_t;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievementrewardreceived;
-- +goose StatementEnd
