-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSkillCooltime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskillcooltime(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select cooltime_data_cnt, data from user_skill_cooltime where char_id = _char_id

--declare _oldata varbinary(8)

--declare _data varbinary(2048)

--declare _cnt int

--SELECT data INTO _oldata from user_skill_cooltime_copy where char_id = _char_id AND skill_cd > GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

--if (@_r_o_w_c_o_u_n_t = 0)

--    select cooltime_data_cnt, data from user_skill_cooltime where char_id = _char_id

--else 

--begin

--    select _cnt = cooltime_data_cnt, _data = data from user_skill_cooltime where char_id = _char_id

--	_cnt := _cnt + 1

--	_data := _data + _oldata

--	select _cnt, _data

--end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillcooltime;
-- +goose StatementEnd
