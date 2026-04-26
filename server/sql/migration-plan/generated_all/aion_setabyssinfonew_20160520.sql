-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAbyssInfoNew_20160520.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssinfonew_20160520(_abyss_id INTEGER, _owner_server INTEGER, _owner_guild INTEGER, _owner_race INTEGER, _defense_cnt INTEGER, _reward BIGINT, _occupy_bonus BIGINT, _user_reward_sum BIGINT, _change_owner_time INTEGER, _cur_pv_p_status INTEGER, _next_pv_p_status INTEGER, _door_upgrade_point INTEGER, _shield_upgrade_point INTEGER, _peace_count INTEGER, _new_owner_char_id INTEGER, _prev_owner_char_id INTEGER, _ownership_bonus_glory_point INTEGER, _last_pv_p_on_time INTEGER, _occupy_point INTEGER, _occupy_count INTEGER, _occupy_reward_count_l INTEGER, _occupy_reward_count_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _is_last_ownership_bonus_updated INT

_is_last_ownership_bonus_updated := 0



/* owner가 달라진 경우 처리 */

IF (_prev_owner_char_id != _new_owner_char_id)

BEGIN

	/* 기존 오너가 있으면 포인트 차감 */

	IF (0 < _prev_owner_char_id)

	BEGIN

		DECLARE _last_ownership_bonus_gp	int

		_last_ownership_bonus_gp := (select COALESCE(last_ownership_bonus_gp, 0) FROM abyss where abyss_id=_abyss_id)

		IF (0 < _last_ownership_bonus_gp)

		BEGIN

			UPDATE user_gp_data SET ownership_bonus_gp -= _last_ownership_bonus_gp where char_id=_prev_owner_char_id

		END

	END



	/* 새 오너가 있으면 포인트 주고 */

	IF (0 < _new_owner_char_id) AND (0 < _ownership_bonus_glory_point)

	BEGIN

		_is_last_ownership_bonus_updated := 1

		IF EXISTS (SELECT char_id FROM user_gp_data WHERE char_id=_new_owner_char_id)

		BEGIN

			UPDATE user_gp_data SET ownership_bonus_gp += _ownership_bonus_glory_point where char_id=_new_owner_char_id

		END

		ELSE

		BEGIN

			INSERT INTO user_gp_data (char_id, glory_point, ownership_bonus_gp) VALUES (_new_owner_char_id, 0, _ownership_bonus_glory_point)

		END

		UPDATE user_data SET today_glory_point += _ownership_bonus_glory_point, this_week_glory_point += _ownership_bonus_glory_point where char_id=_new_owner_char_id

	END

END



if EXISTS (SELECT abyss_id FROM abyss(updlock) WHERE abyss_id= _abyss_id)

begin

	IF (0 < _is_last_ownership_bonus_updated)

	BEGIN

		UPDATE abyss SET owner_guild = _owner_guild, owner_race =  _owner_race, defense_count =  _defense_cnt, reward = _reward, 	

			cur_pvp_status = _cur_pv_p_status, next_pvp_status = _next_pv_p_status, door_upgrade_point = _door_upgrade_point, shield_upgrade_point = _shield_upgrade_point,

			peace_count = _peace_count, occupy_bonus = _occupy_bonus, user_reward_sum = _user_reward_sum, change_owner_time = _change_owner_time, owner_server = _owner_server,

			owner_char_id=_new_owner_char_id, last_ownership_bonus_gp=_ownership_bonus_glory_point, last_pvp_on_time = _last_pv_p_on_time, occupy_point = _occupy_point, occupy_count = _occupy_count,

			occupy_reward_count_l = _occupy_reward_count_l, occupy_reward_count_d = _occupy_reward_count_d

			WHERE abyss_id= _abyss_id

	END

	ELSE

	BEGIN

		UPDATE abyss SET owner_guild = _owner_guild, owner_race =  _owner_race, defense_count =  _defense_cnt, reward = _reward, 	

			cur_pvp_status = _cur_pv_p_status, next_pvp_status = _next_pv_p_status, door_upgrade_point = _door_upgrade_point, shield_upgrade_point = _shield_upgrade_point,

			peace_count = _peace_count, occupy_bonus = _occupy_bonus, user_reward_sum = _user_reward_sum, change_owner_time = _change_owner_time, owner_server = _owner_server,

			owner_char_id=_new_owner_char_id, last_pvp_on_time = _last_pv_p_on_time, occupy_point = _occupy_point, occupy_count = _occupy_count,

			occupy_reward_count_l = _occupy_reward_count_l, occupy_reward_count_d = _occupy_reward_count_d

			WHERE abyss_id= _abyss_id

	END

end

else

begin		

	IF (0 < _is_last_ownership_bonus_updated)

	BEGIN

		INSERT abyss (abyss_id, owner_server, owner_guild, owner_race, defense_count, reward, occupy_bonus, user_reward_sum, change_owner_time, last_ownership_bonus_gp, last_pvp_on_time, occupy_point, occupy_count, occupy_reward_count_l, occupy_reward_count_d) VALUES (_abyss_id, _owner_server, _owner_guild, _owner_race, _defense_cnt, _reward, _occupy_bonus, _user_reward_sum, _change_owner_time, _ownership_bonus_glory_point, _last_pv_p_on_time, _occupy_point, _occupy_count, _occupy_reward_count_l, _occupy_reward_count_d)

	END

	ELSE

	BEGIN

		INSERT abyss (abyss_id, owner_server, owner_guild, owner_race, defense_count, reward, occupy_bonus, user_reward_sum, change_owner_time, last_ownership_bonus_gp, last_pvp_on_time, occupy_point, occupy_count, occupy_reward_count_l, occupy_reward_count_d) VALUES (_abyss_id, _owner_server, _owner_guild, _owner_race, _defense_cnt, _reward, _occupy_bonus, _user_reward_sum, _change_owner_time, 0, _last_pv_p_on_time, _occupy_point, _occupy_count, _occupy_reward_count_l, _occupy_reward_count_d)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssinfonew_20160520;
-- +goose StatementEnd
