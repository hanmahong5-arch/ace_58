-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildItemList_20120102.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguilditemlist_20120102(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT   id, name_id, slot_id, amount, tid, slot, producer, expired_time, buy_amount, buy_duration	

FROM	user_item 

WHERE	warehouse = 3 AND char_id = _guild_id

ORDER BY slot_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguilditemlist_20120102;
-- +goose StatementEnd
