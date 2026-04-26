-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_VenderItem_DeleteByCharId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_venderitem_deletebycharid(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	DELETE FROM vendor_item_light where char_id = _char_id

	DELETE FROM vendor_item_dark where char_id = _char_id

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_venderitem_deletebycharid;
-- +goose StatementEnd
