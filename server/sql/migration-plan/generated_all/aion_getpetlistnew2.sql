-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetPetListNew2.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpetlistnew2(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


DECLARE _utc_adjust BIGINT

_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())

SELECT	id,name_id,slot_id,name,function_data1,function_data1_ex1,function_data1_ex2,function_data1_ex3,function_data2,function_data2_ex1,function_data2_ex2,function_data2_ex3,GetUnixtimeWithUTCAdjust(create_date, _utc_adjust),visual_data_size,visual_data,expired_time

FROM user_pet

WHERE char_id = _char_id


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetlistnew2;
-- +goose StatementEnd
