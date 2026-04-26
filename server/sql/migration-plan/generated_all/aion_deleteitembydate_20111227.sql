-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteItemByDate_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitembydate_20111227(_date INTEGER, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 삭제된 지 _date일이 지난 _warehouse의 아이템을 실제로 제거한다.



-- DECLARE _curdate DATETIME

-- _curdate := NOW()

-- DELETE FROM user_item WHERE warehouse = _warehouse AND DATEDIFF(d, update_date, _curdate) > _date



DECLARE _deletedate DATETIME

_deletedate := DATEADD(d, -_date, NOW())



CREATE TABLE #deletedItem (

	id int NOT NULL

)



INSERT INTO #deletedItem with (tablock) SELECT ID from user_item where warehouse = _warehouse AND tid = 0 AND update_date < _deletedate



delete from user_item_option where ID in (select * from #deletedItem)

delete from user_item_charge where ID in (select * from #deletedItem)

Delete from user_item_polish where id in (select * from #deletedItem)

delete from user_item_attribute where id in (select * from #deleteditem)

DELETE FROM user_item WHERE ID in (select * from #deletedItem)



DROP TABLE #deletedItem










/****** Object:  StoredProcedure aion_DeleteItem_20111227    Script Date: 2014-03-14 오후 1:29:36 ******/

SET ANSI_NULLS ON;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitembydate_20111227;
-- +goose StatementEnd
