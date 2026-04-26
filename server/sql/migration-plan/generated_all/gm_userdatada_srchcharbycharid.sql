-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchCharByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	    select	convert(nvarchar,create_date,20) create_date,

			    convert(nvarchar,last_login_time,20) last_login_time,

			    convert(nvarchar,last_logout_time,20) last_logout_time,

			    convert(nvarchar,guild_update_date,20) guild_update_date, 

			    COALESCE(login_server, org_server) login_server 

			    , COALESCE(g.glory_point, 0) as glory_point, COALESCE(g.ownership_bonus_gp, 0) as ownership_bonus_gp

			    , u.*

			    , COALESCE(e.use_bot_channel,0) as use_bot_channel

			    , COALESCE(ude.exps_login_reward_time, 0) as exps_login_reward_time, COALESCE(ude.exps_npckill_reward_num, 0) as exps_npckill_reward_num, COALESCE(ude.creativity_point, 0) as creativity_point, COALESCE(ude.usecp_resetcount, 0) as usecp_resetcount, COALESCE(ude.next_usecp_resetcount_dec_time, 0) as next_usecp_resetcount_dec_time

			    , COALESCE(ude.familiar_func_expireTime, 0) as familiar_func_expireTime, COALESCE(ude.familiar_energy, 0) as familiar_energy, COALESCE(ude.familiar_energy_autocharge, 0) as familiar_energy_autocharge, COALESCE(ude.familiar_func_autocharge, 0) as familiar_func_autocharge

			    , COALESCE(e.prevSeasonReward, 0) as prevSeasonReward, COALESCE(e.currentSeasonReward, 0) as currentSeasonReward

	    from	user_data (nolock) u

	    left join user_gp_data (nolock) g on g.char_id = u.char_id

	    left join user_extra_info (nolock) e on u.char_id = e.char_id

	    left join user_data_ext (nolock) ude on u.char_id = ude.char_id

	    where	u.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchcharbycharid;
-- +goose StatementEnd
