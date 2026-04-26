-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemDropCtrlInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemdropctrlinfo(_item_id INTEGER, _item_cur_count INTEGER, _next_reset_time BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION




IF EXISTS (SELECT item_name_id FROM item_drop_ctrl(UPDLOCK) WHERE item_name_id=_item_id)

begin

	UPDATE item_drop_ctrl

	SET cur_count = _item_cur_count, next_reset_time = _next_reset_time

	WHERE item_name_id = _item_id

end

else

begin

	INSERT item_drop_ctrl(item_name_id, cur_count, next_reset_time)

	VALUES (_item_id, _item_cur_count, _next_reset_time)	

end




COMMIT TRANSACTION;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemdropctrlinfo;
-- +goose StatementEnd
