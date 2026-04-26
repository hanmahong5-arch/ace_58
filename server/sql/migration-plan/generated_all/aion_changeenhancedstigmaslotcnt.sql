-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChangeEnhancedStigmaSlotCnt.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changeenhancedstigmaslotcnt(_char_i_d INTEGER, _cnt INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 존재하는 이름 검사

IF NOT EXISTS (SELECT char_id FROM user_data WHERE char_id=_char_i_d AND (delete_date = 0 OR (delete_date > GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0))))

	return -1



UPDATE user_data

SET 	enhanced_stigma_slot_cnt = _cnt

WHERE char_id  =  _char_i_d






IF @_e_r_r_o_r <> 0

	return 0



return _char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeenhancedstigmaslotcnt;
-- +goose StatementEnd
