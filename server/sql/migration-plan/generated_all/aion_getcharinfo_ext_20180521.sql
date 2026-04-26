-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharInfo_Ext_20180521.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharinfo_ext_20180521(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin 

	select 

	exps_login_reward_time,

	exps_npckill_reward_num,

	creativity_point,

	usecp_resetcount,

	next_usecp_resetcount_dec_time,

	familiar_func_expireTime,

	familiar_energy,

	familiar_energy_autocharge,

	familiar_func_autocharge,

	last_transform_id,

	last_transform_scroll_id,

	last_summon_familiar,

	last_collection_id

	from user_data_ext with(nolock) where char_id = _char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfo_ext_20180521;
-- +goose StatementEnd
