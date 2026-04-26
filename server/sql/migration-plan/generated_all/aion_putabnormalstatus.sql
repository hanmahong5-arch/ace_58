-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutAbnormalStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putabnormalstatus(_char_id INTEGER, _skill_id INTEGER, _skill_level INTEGER, _target_slot INTEGER, _remain1 INTEGER, _remain2 INTEGER, _remain3 INTEGER, _remain4 INTEGER, _interval_value1 INTEGER, _interval_value2 INTEGER, _interval_value3 INTEGER, _interval_value4 INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_abnormal_status(char_id, skill_id, skill_level, target_slot, effect_remain1, effect_remain2, effect_remain3, effect_remain4, interval_value1, interval_value2, interval_value3, interval_value4, logout_time)

VALUES (_char_id, _skill_id, _skill_level, _target_slot, _remain1, _remain2, _remain3, _remain4, _interval_value1,  _interval_value2,  _interval_value3,  _interval_value4, GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0));
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putabnormalstatus;
-- +goose StatementEnd
