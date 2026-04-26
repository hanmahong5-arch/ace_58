-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateDisassemblyRetry.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatedisassemblyretry(_char_id INTEGER, _item_id BIGINT, _retry_count INTEGER, _delete INTEGER, _name1 INTEGER, _count1 INTEGER, _name2 INTEGER, _count2 INTEGER, _name3 INTEGER, _count3 INTEGER, _name4 INTEGER, _count4 INTEGER, _name5 INTEGER, _count5 INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 

	begin tran

	update user_disassembly_retry set retryCount = _retry_count, isDelete = _delete, nameId1 = _name1, ItemCount1 = _count1, 

		nameId2 = _name2, ItemCount2 = _count2, nameId3 = _name3, ItemCount3 = _count3, nameId4 = _name4, ItemCount4 = _count4, 

		nameId5 = _name5, ItemCount5 = _count5, UpdateDate = NOW()

	where charId = _char_id and ItemId = _item_id 

	

	if @_r_o_w_c_o_u_n_t = 0

	begin

		insert into user_disassembly_retry values(_char_id, _item_id, _retry_count, _delete, _name1, _count1, 

				_name2, _count2, _name3, _count3, _name4, _count4, _name5, _count5, NOW())

	end

	commit

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatedisassemblyretry;
-- +goose StatementEnd
