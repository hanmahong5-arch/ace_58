-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ReplaceAbnormalStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_replaceabnormalstatus(_char_id INTEGER, _skill_id INTEGER, _skill_level INTEGER, _target_slot INTEGER, _remain1 INTEGER, _remain2 INTEGER, _remain3 INTEGER, _remain4 INTEGER, _interval_value1 INTEGER, _interval_value2 INTEGER, _interval_value3 INTEGER, _interval_value4 INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT char_id FROM user_abnormal_status(UPDLOCK) WHERE  char_id=_char_id and skill_id=_skill_id) 

begin

	UPDATE user_abnormal_status

	SET skill_level=_skill_level, target_slot=_target_slot, 

		effect_remain1=_remain1, effect_remain2=_remain2, effect_remain3=_remain3, effect_remain4=_remain4, 

		interval_value1=_interval_value1, interval_value2=_interval_value2, interval_value3=_interval_value3, interval_value4=_interval_value4	

	WHERE  char_id=_char_id and skill_id=_skill_id 

end

else

begin

	INSERT user_abnormal_status(char_id, skill_id, skill_level, target_slot, effect_remain1, effect_remain2, effect_remain3, effect_remain4, interval_value1, interval_value2, interval_value3, interval_value4)

	VALUES (_char_id, _skill_id, _skill_level, _target_slot, _remain1, _remain2, _remain3, _remain4, _interval_value1,  _interval_value2,  _interval_value3,  _interval_value4)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_replaceabnormalstatus;
-- +goose StatementEnd
