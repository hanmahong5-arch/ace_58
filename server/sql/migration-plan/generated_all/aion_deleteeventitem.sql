-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteEventItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteeventitem(_itemid BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
IF NOT EXISTS (SELECT object_id FROM sys.tables WHERE name = 'aionDeletedEventItemCount')

BEGIN

	CREATE TABLE aionDeletedEventItemCount(

		delete_id int NOT NULL,

		char_id int NOT NULL,

		item_count bigint NOT NULL,

		apply_date datetime NOT NULL,

		event_item bigint NOT NULL

	)

END



declare _curr_time datetime



_curr_time := NOW()

	

insert into aionDeletedEventItemCount (char_id, item_count, apply_date, event_item)

select user_item.char_id, sum(amount) as item_count, _curr_time, _itemid

from user_item

where user_item.name_id = _itemid and (warehouse = 0 or warehouse = 1 OR (warehouse >= 30 AND warehouse < 50))

group by user_item.char_id 



UPDATE user_item

SET warehouse=10, update_date=_curr_time

WHERE name_id=_itemid



select *

from aionDeletedEventItemCount

where apply_date = _curr_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteeventitem;
-- +goose StatementEnd
