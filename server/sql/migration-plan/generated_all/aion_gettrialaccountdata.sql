-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetTrialAccountData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gettrialaccountdata(_account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	select reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum from trial_account_data(nolock) WHERE account_id=_account_id

	


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gettrialaccountdata;
-- +goose StatementEnd
