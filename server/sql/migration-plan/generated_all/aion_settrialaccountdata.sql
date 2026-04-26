-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetTrialAccountData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settrialaccountdata(_account_id INTEGER, _reset_time INTEGER, _sell_gold BIGINT, _trade_gold BIGINT, _decompose_sum INTEGER, _gather_sum INTEGER, _extract_gather_sum INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	if EXISTS (SELECT account_id FROM trial_account_data(UPDLOCK) WHERE account_id=_account_id) 

	begin

		UPDATE trial_account_data

		SET 

			reset_time = _reset_time,

			sell_gold_sum = _sell_gold,

			trade_gold_sum = _trade_gold,

			decompose_sum = _decompose_sum,

			gather_sum = _gather_sum,

			extract_gather_sum = _extract_gather_sum

		WHERE account_id=_account_id

	end

	else

	begin

		INSERT trial_account_data(account_id, reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum) 

		VALUES (_account_id, _reset_time, _sell_gold, _trade_gold, _decompose_sum, _gather_sum, _extract_gather_sum)

	end



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settrialaccountdata;
-- +goose StatementEnd
