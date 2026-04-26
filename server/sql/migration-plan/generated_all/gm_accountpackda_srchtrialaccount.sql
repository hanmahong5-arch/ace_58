-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AccountPackDA_SrchTrialAccount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_accountpackda_srchtrialaccount(_account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted			

			

			select reset_time, sell_gold_sum, trade_gold_sum, decompose_sum, gather_sum, extract_gather_sum

			from trial_account_data 

			where account_id=_account_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_accountpackda_srchtrialaccount;
-- +goose StatementEnd
