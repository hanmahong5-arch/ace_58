-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetMonsterAchievement.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmonsterachievement(_char_id INTEGER, _achieve_id INTEGER, _achieved_count INTEGER, _achieved_grade INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_monster_achievement

	SET		achieved_count = _achieved_count, achieved_grade = _achieved_grade

	WHERE	char_id = _char_id AND achieve_id = _achieve_id

	

	IF (@_r_o_w_c_o_u_n_t = 0)

	BEGIN

		INSERT INTO user_monster_achievement (char_id, achieve_id, achieved_count, achieved_grade, reward_received)

		VALUES (_char_id, _achieve_id, _achieved_count, _achieved_grade, 0)

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievement;
-- +goose StatementEnd
