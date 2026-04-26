-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutItemBind.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putitembind(_id BIGINT, _actor_type INTEGER, _actor_value INTEGER, _bind_warehouse INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN TRANSACTION

UPDATE user_item SET slot_id = -1, warehouse = _bind_warehouse, update_date = NOW() WHERE id = _id

IF @_e_r_r_o_r = 0

	BEGIN

		INSERT INTO user_item_bind(item_id, actor_type, actor_value) VALUES (_id, _actor_type, _actor_value)

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
DROP FUNCTION IF EXISTS aion_putitembind;
-- +goose StatementEnd
