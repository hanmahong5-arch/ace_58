-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RegisterGameMoneyTradePhase1.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_registergamemoneytradephase1(_id BIGINT, _seller INTEGER, _qina BIGINT, _cash BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	Insert Into game_money_trade(seller, qina, cash) Values(_seller, _qina, _cash);

	IF @_r_o_w_c_o_u_n_t = 0

		return -1;	--Fail to insert

	Else

	Begin

		_id := @_identity;

		return 0

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_registergamemoneytradephase1;
-- +goose StatementEnd
