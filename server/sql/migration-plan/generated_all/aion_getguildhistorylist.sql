-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildHistoryList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildhistorylist(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- BEGIN OF QUERY

	SELECT eventDate, eventType, eventParam, eventParam2 FROM guild_history WHERE guild_id = _guild_id ORDER BY id DESC

-- END OF QUERY
 /* LIMIT 1000 appended */ LIMIT 1000;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildhistorylist;
-- +goose StatementEnd
