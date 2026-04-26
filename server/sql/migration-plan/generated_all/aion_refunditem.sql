-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RefundItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_refunditem(_item_name_id INTEGER, _tid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_mail SET item_id = 0, item_nameid = 0, item_amount = 0 WHERE item_id IN (SELECT id FROM user_item WHERE tid = _tid AND name_id = _item_name_id)

	IF @_e_r_r_o_r <> 0

	    BEGIN

		RETURN 0;

	    END

	UPDATE user_item SET warehouse = 13 WHERE tid = _tid AND name_id = _item_name_id

--	DELETE FROM user_item WHERE tid = _tid AND name_id = _item_name_id	

	IF @_e_r_r_o_r <> 0

	    BEGIN

		RETURN 0;

	    END

	-- Success

	RETURN 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_refunditem;
-- +goose StatementEnd
