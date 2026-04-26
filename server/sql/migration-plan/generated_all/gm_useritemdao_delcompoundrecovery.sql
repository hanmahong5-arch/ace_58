-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_DelCompoundRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_delcompoundrecovery(_char_id INTEGER, _item_id BIGINT, _warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _main_item_dbid bigint



begin tran



	SELECT main_item_dbid INTO _main_item_dbid from user_item(updlock) where id = _item_id and char_id = _char_id

	if (@_rowcount = 0)

	begin

		rollback tran

		return 1

	end



	if not EXISTS (select char_id from user_item(UPDLOCK) where char_id=_char_id and warehouse=16 and main_item_dbid=_main_item_dbid)

	begin	

		update user_item set warehouse = _warehouse where char_id=_char_id and warehouse=17 and id = _item_id and char_id = _char_id

	end

	else

	begin

		rollback tran

		return 2

	end



commit tran

return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_delcompoundrecovery;
-- +goose StatementEnd
