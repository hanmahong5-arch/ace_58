-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharInfo_ForRefreshAcc_20121210.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharinfo_forrefreshacc_20121210(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _utc_adjust BIGINT

_utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())





SELECT char_id

      ,account_id

      ,org_server

      ,lev

      ,create_date

      ,last_login_time

      ,last_logout_time

      /*

      ,GetUnixtimeWithUTCAdjust(create_date, _utc_adjust) as create_time

      ,GetUnixtimeWithUTCAdjust(last_login_time, _utc_adjust) as login_time

      ,GetUnixtimeWithUTCAdjust(last_logout_time, _utc_adjust) as logout_time

      */

      ,delete_date

      ,delete_complete_date

      ,class

      ,race

  FROM user_data

  WHERE char_id=_user_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfo_forrefreshacc_20121210;
-- +goose StatementEnd
