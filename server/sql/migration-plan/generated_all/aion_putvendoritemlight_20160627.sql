-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutVendorItemLight_20160627.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putvendoritemlight_20160627(_char_id INTEGER, _user_item_id BIGINT, _user_price BIGINT, _sale_price BIGINT, _commit_amount BIGINT, _remain_amount BIGINT, _commit_date INTEGER, _buy_partial INTEGER, _after_unit_fee BIGINT, _after_unit_tax BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	if not exists(SELECT user_item_id from vendor_item_light(updlock) where user_item_id = _user_item_id)

	begin



	INSERT INTO vendor_item_light

		(char_id, user_item_id, user_price, sale_price, commit_amount, 

		remain_amount, commit_date, can_buy_partial, afterUnitFee, afterUnitTax)

	VALUES   (_char_id, _user_item_id, _user_price, _sale_price, _commit_amount, 

		_remain_amount, _commit_date, _buy_partial, _after_unit_fee, _after_unit_tax)

	end

	else

	begin


		RETURN 0

	end


	IF @_e_r_r_o_r <> 0

		RETURN 0

	RETURN @_i_d_e_n_t_i_t_y

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putvendoritemlight_20160627;
-- +goose StatementEnd
