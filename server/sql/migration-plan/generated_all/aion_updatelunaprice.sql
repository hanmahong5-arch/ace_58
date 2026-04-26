-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateLunaPrice.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatelunaprice(_char_id INTEGER, _luna_id INTEGER, _use_count INTEGER, _reset_type INTEGER, _reset_week_value INTEGER, _reset_time_value INTEGER, _create_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin	


	begin tran

	update user_luna_price set use_count = _use_count, update_time = NOW() where char_id = _char_id and luna_id = _luna_id

	if @_r_o_w_c_o_u_n_t = 0

	begin

		insert into user_luna_price (char_id, luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time)

		values (_char_id, _luna_id, _use_count, _reset_type, _reset_week_value, _reset_time_value, _create_time)

	end	

	commit tran


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatelunaprice;
-- +goose StatementEnd
