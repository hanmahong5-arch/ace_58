-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetResetGuildAccGoldHistory.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setresetguildaccgoldhistory(_event_type INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
delete from guild_warehouse_history where eventType = _event_type;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setresetguildaccgoldhistory;
-- +goose StatementEnd
