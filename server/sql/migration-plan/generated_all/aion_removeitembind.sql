-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemoveItemBind.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeitembind(_id BIGINT, _remove_warehouse INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION

DELETE FROM user_item_bind WHERE item_id = _id

-- 이미 바인드에서 빠진 경우에 warehouse중복처리되지 않도록

IF @_r_o_w_c_o_u_n_t <> 0

	BEGIN

		UPDATE user_item SET warehouse = _remove_warehouse, update_date = NOW() WHERE id = _id

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
DROP FUNCTION IF EXISTS aion_removeitembind;
-- +goose StatementEnd
