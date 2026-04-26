-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ResetCharRatePoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetcharratepoint(_rate_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	DELETE FROM user_rate where rate_id = _rate_id	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetcharratepoint;
-- +goose StatementEnd
