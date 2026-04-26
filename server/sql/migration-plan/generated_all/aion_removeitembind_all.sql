-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveItemBind_All.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeitembind_all(_rollback_warehouse INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION

UPDATE user_item SET warehouse = _rollback_warehouse, update_date = NOW() WHERE id IN (SELECT DISTINCT item_id FROM user_item_bind)

DELETE FROM user_item_bind

IF @_e_r_r_o_r = 0

	BEGIN

		COMMIT TRANSACTION

		RETURN 0

	END

ELSE

	BEGIN

		ROLLBACK TRANSACTION

		RETURN 1

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeitembind_all;
-- +goose StatementEnd
