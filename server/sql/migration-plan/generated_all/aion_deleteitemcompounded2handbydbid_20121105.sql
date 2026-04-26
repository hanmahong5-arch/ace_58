-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteItemCompounded2HandByDbId_20121105.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitemcompounded2handbydbid_20121105(_id BIGINT, _warehouse INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
declare _ret int



/*DELETE FROM user_item_compounded_twohand WHERE id = _id*/






	if _warehouse = 17

		begin

			UPDATE user_item SET warehouse = _warehouse WHERE id = _id

		end

	else

		begin

			UPDATE user_item SET warehouse = _warehouse, update_date = NOW() WHERE id = _id

		end

	

	_ret := @_r_o_w_c_o_u_n_t




return _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitemcompounded2handbydbid_20121105;
-- +goose StatementEnd
