-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ProcessLegionDominionTakeOver.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_processlegiondominiontakeover(_take_over_time BIGINT, _server_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	DECLARE _lastest_take_over_time bigint

	_lastest_take_over_time := COALESCE((select max(take_over_processed_time) from legion_dominion_rankings where server_id=_server_id), 0)



	IF (0 < _take_over_time and _lastest_take_over_time < _take_over_time)

	begin

		insert into legion_dominion_rankings values(0, 0, 0, 0, 0, _take_over_time, _server_id)

		update legion_dominion_rankings set take_over_processed_time=_take_over_time where take_over_processed_time=0 and server_id=_server_id

		/* 오래된 기록(30일 전) 삭제*/

		delete from legion_dominion_rankings where take_over_processed_time < (_take_over_time-30*24*60*60) and server_id=_server_id

	end

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_processlegiondominiontakeover;
-- +goose StatementEnd
