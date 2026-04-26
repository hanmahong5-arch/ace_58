-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguilditem(_guild_id INTEGER, _user_item_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT guild_item (guild_id, item_id) VALUES (_guild_id, _user_item_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguilditem;
-- +goose StatementEnd
