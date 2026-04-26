-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateWarehouseForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updatewarehouseforbuyrecovery(_db_id BIGINT, _char_id INTEGER, _warehouse INTEGER, _new_warehouse INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE	user_item

	SET		warehouse = _new_warehouse

	WHERE	id = _db_id

	and		char_id = _char_id

	and		warehouse = _warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updatewarehouseforbuyrecovery;
-- +goose StatementEnd
