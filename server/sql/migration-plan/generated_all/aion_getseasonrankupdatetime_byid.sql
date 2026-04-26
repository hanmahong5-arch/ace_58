-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSeasonRankUpdateTime_byId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getseasonrankupdatetime_byid(_rank_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

		

	select season_update_time from user_rank_update_time where rank_id = _rank_id

		

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getseasonrankupdatetime_byid;
-- +goose StatementEnd
