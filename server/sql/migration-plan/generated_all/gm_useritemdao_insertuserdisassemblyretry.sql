-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertUserDisassemblyRetry.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertuserdisassemblyretry(_char_id INTEGER, _item_id BIGINT, _retry_count INTEGER, _delete INTEGER, _name_id1 INTEGER, _item_count1 INTEGER, _name_id2 INTEGER, _item_count2 INTEGER, _name_id3 INTEGER, _item_count3 INTEGER, _name_id4 INTEGER, _item_count4 INTEGER, _name_id5 INTEGER, _item_count5 INTEGER, _update_date TIMESTAMPTZ)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	INSERT INTO user_disassembly_retry (charId, ItemId, retryCount, isDelete, nameId1, ItemCount1, nameId2, ItemCount2, nameId3, ItemCount3, nameId4, ItemCount4, nameId5, ItemCount5, UpdateDate)

	VALUES (_char_id, _item_id, _retry_count, _delete, _name_id1, _item_count1, _name_id2, _item_count2, _name_id3, _item_count3, _name_id4, _item_count4, _name_id5, _item_count5, _update_date)

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertuserdisassemblyretry;
-- +goose StatementEnd
