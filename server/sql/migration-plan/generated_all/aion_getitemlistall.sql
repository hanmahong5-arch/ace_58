-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItemListAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlistall(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



SELECT   id, name_id, slot_id, amount, tid, slot, producer, expired_time, buy_amount, buy_duration, warehouse	

FROM user_item

WHERE char_id = _char_id and warehouse not in (2,6,7, 10, 11, 12) AND export_id = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlistall;
-- +goose StatementEnd
