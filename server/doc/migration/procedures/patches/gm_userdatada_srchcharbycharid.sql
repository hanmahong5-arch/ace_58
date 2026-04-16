-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	TO_CHAR(create_date, 'YYYY-MM-DD HH24:MI:SS') create_date, TO_CHAR(last_login_time, 'YYYY-MM-DD HH24:MI:SS') last_login_time, TO_CHAR(last_logout_time, 'YYYY-MM-DD HH24:MI:SS') last_logout_time, TO_CHAR(guild_update_date, 'YYYY-MM-DD HH24:MI:SS') guild_update_date, COALESCE(login_server, org_server) login_server , COALESCE(g.glory_point, 0) as glory_point, COALESCE(g.ownership_bonus_gp, 0) as ownership_bonus_gp , u.* , COALESCE(e.use_bot_channel,0) as use_bot_channel , COALESCE(ude.exps_login_reward_time, 0) as exps_login_reward_time, COALESCE(ude.exps_npckill_reward_num, 0) as exps_npckill_reward_num, COALESCE(ude.creativity_point, 0) as creativity_point, COALESCE(ude.usecp_resetcount, 0) as usecp_resetcount, COALESCE(ude.next_usecp_resetcount_dec_time, 0) as next_usecp_resetcount_dec_time , COALESCE(ude.familiar_func_expireTime, 0) as familiar_func_expireTime, COALESCE(ude.familiar_energy, 0) as familiar_energy, COALESCE(ude.familiar_energy_autocharge, 0) as familiar_energy_autocharge, COALESCE(ude.familiar_func_autocharge, 0) as familiar_func_autocharge , COALESCE(e.prevSeasonReward, 0) as prevSeasonReward, COALESCE(e.currentSeasonReward, 0) as currentSeasonReward from	user_data  u left join user_gp_data  g on g.char_id = u.char_id left join user_extra_info  e on u.char_id = e.char_id left join user_data_ext  ude on u.char_id = ude.char_id where	u.char_id = p_char_id;
END;
$$;
