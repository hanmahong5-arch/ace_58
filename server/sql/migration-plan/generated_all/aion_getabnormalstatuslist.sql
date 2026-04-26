-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAbnormalStatusList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabnormalstatuslist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _time int

declare _cd int

declare _sk int = 12885

while(_sk < 12895)

begin

if (EXISTS(SELECT * FROM user_abnormal_status WHERE skill_id = _sk AND char_id = _char_id))

BEGIN

	 SELECT effect_remain2, _time = logout_time INTO _cd FROM user_abnormal_status WHERE skill_id = _sk AND char_id = _char_id

	 declare _time int

	 _time := (GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) - _time) * 1000

	 if (_cd > _time)

	 Begin

	   UPDATE user_abnormal_status SET effect_remain2 = _cd - _time, effect_remain3 = _cd - _time, effect_remain4 = _cd - _time WHERE skill_id = _sk AND char_id = _char_id

	 end

	 else 

	 Begin

	   DELETE FROM user_abnormal_status WHERE skill_id = _sk AND char_id = _char_id

	 End

END

_sk := _sk + 1

end



SELECT skill_id, skill_level, target_slot, effect_remain1, effect_remain2, effect_remain3, effect_remain4, interval_value1, interval_value2, interval_value3, interval_value4 

FROM user_abnormal_status

WHERE char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabnormalstatuslist;
-- +goose StatementEnd
