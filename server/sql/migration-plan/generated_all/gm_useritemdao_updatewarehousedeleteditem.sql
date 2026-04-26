-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateWarehouseDeletedItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updatewarehousedeleteditem(_char_id INTEGER, _db_id BIGINT, _warehouse INTEGER, _return_value INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _error INT

DECLARE _count INT

_return_value := 0



UPDATE user_item SET warehouse=_warehouse

where id=_db_id and char_id=_char_id and warehouse=10



SELECT @_e_r_r_o_r, _count = @_r_o_w_c_o_u_n_t

IF _error <> 0 OR _count < 1

	RETURN



_return_value := 1

RETURN INTO _error;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updatewarehousedeleteditem;
-- +goose StatementEnd
