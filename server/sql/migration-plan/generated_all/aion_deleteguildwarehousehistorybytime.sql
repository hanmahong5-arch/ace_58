-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteGuildWarehouseHistoryByTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteguildwarehousehistorybytime(_guild_id INTEGER, _check_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM guild_warehouse_history 

where eventDate < _check_time /* 시간이 지났고 */	

	and guild_id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguildwarehousehistorybytime;
-- +goose StatementEnd
