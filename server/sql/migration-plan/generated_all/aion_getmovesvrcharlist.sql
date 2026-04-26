-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMoveSvrCharList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmovesvrcharlist(_server_id INTEGER, _last_check_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _utc_adjust BIGINT

_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())





select fromCharacterId

from AionAddedService

where fromServer = _server_id and status = 1 and serviceFlag = 0 and serviceType = 4 and applyDate >= dateadd(ss,_last_check_time+_utc_adjust,'1970-01-01');
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmovesvrcharlist;
-- +goose StatementEnd
