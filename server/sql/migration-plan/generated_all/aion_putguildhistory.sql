-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutGuildHistory.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putguildhistory(_guild_id INTEGER, _event_date INTEGER, _event_type INTEGER, _event_param TEXT, _event_param2 TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT guild_history(guild_id, eventDate, eventType, eventParam, eventParam2)

VALUES (_guild_id, _event_date, _event_type, _event_param, _event_param2);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putguildhistory;
-- +goose StatementEnd
