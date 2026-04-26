-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_LoadLegionDominionLastestTakeOverTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionlastesttakeovertime(_server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	DECLARE _lastest_take_over_time bigint

	_lastest_take_over_time := COALESCE((select max(take_over_processed_time) from legion_dominion_rankings where server_id=_server_id), 0)

	return _lastest_take_over_time

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionlastesttakeovertime;
-- +goose StatementEnd
