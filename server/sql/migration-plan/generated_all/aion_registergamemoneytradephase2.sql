-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RegisterGameMoneyTradePhase2.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_registergamemoneytradephase2(_id BIGINT, _seller INTEGER, _qina BIGINT, _request_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	If EXISTS(Select id From game_money_trade with (nolock) Where id=_id and seller=_seller and qina=_qina and state IS NULL)

	Begin

		Update game_money_trade with (updlock) set state=1, register_date=NOW(), request_id=_request_id Where id=_id

		If @_r_o_w_c_o_u_n_t = 1

			return 0

		Else

			return -2 -- Fail to update

	End

	Else

	Begin

		return -1	-- Can't find 

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_registergamemoneytradephase2;
-- +goose StatementEnd
