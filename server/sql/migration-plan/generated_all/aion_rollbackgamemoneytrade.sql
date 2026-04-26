-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_rollbackGameMoneyTrade.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_rollbackgamemoneytrade(_request_id TEXT, _id BIGINT, _seller INTEGER, _qina BIGINT, _cash BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    Update game_money_trade Set state=-3, complete_date=NOW() Where request_id=_request_id and state=1

    If @_r_o_w_c_o_u_n_t = 1

    Begin

		SELECT id, _seller=seller, _qina=qina, _cash=cash INTO _id From game_money_trade Where request_id=_request_id

		return 0

	End

	Else

	Begin

		return -1

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_rollbackgamemoneytrade;
-- +goose StatementEnd
