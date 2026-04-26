-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutVendorItemDark_20140610.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putvendoritemdark_20140610(_char_id INTEGER, _user_item_id BIGINT, _user_price BIGINT, _sale_price BIGINT, _commit_amount BIGINT, _remain_amount BIGINT, _commit_date INTEGER, _buy_partial INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
if not exists(SELECT user_item_id from vendor_item_dark(updlock) where user_item_id = _user_item_id)

begin

INSERT INTO vendor_item_dark

	(char_id, user_item_id, user_price, sale_price, commit_amount, 

	remain_amount, commit_date, can_buy_partial)

VALUES   (_char_id, _user_item_id, _user_price, _sale_price, _commit_amount, 

	_remain_amount, _commit_date, _buy_partial)

end

else

begin


	RETURN 0

end


IF @_e_r_r_o_r <> 0

	RETURN 0

RETURN @_i_d_e_n_t_i_t_y;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putvendoritemdark_20140610;
-- +goose StatementEnd
