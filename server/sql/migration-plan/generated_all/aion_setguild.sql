-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuild.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguild(_guild_id INTEGER, _master_id INTEGER, _level INTEGER, _sub_master_right INTEGER, _officer_right INTEGER, _member_right INTEGER, _newbie_right INTEGER, _point BIGINT, _fund BIGINT, _this_week_target_t_l_d INTEGER, _last_week_target_t_l_d INTEGER, _t_l_d_update_time BIGINT, _delete__requested INTEGER, _delete__time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild

SET master_id=_master_id, level=_level, point=_point, fund=_fund, 

	submaster_right=_sub_master_right, officer_right=_officer_right, 

	member_right=_member_right, newbie_right=_newbie_right,

	this_week_tld = _this_week_target_t_l_d, last_week_tld = _last_week_target_t_l_d, tld_update_time = _t_l_d_update_time,

	delete_requested=_delete__requested, delete_time=_delete__time,

	change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

WHERE id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguild;
-- +goose StatementEnd
