-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMonsterAchievement_UpdateOrInsert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermonsterachievement_updateorinsert(_char_id INTEGER, _achieve_id INTEGER, _achieved_count INTEGER, _achieved_grade INTEGER, _reward_received INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	UPDATE user_monster_achievement SET char_id=_char_id, achieve_id=_achieve_id, achieved_count=_achieved_count, achieved_grade=_achieved_grade, reward_received=_reward_received

	WHERE char_id=_char_id and achieve_id=_achieve_id



	IF @_r_o_w_c_o_u_n_t = 0

		INSERT into user_monster_achievement(char_id, achieve_id, achieved_count, achieved_grade, reward_received)

		VALUES(_char_id, _achieve_id, _achieved_count, _achieved_grade, _reward_received)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermonsterachievement_updateorinsert;
-- +goose StatementEnd
