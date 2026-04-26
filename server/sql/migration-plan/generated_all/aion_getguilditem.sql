-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguilditem(_guild_id INTEGER, _user_item_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM guild_item WHERE guild_id = _guild_id AND item_id = _user_item_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguilditem;
-- +goose StatementEnd
