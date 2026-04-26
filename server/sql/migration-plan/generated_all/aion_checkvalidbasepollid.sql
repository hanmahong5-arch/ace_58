-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckValidBasePollId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkvalidbasepollid(_base_poll_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- 기반 설문이 있음: 정상

IF EXISTS (SELECT poll_id FROM poll_info WHERE poll_id = _base_poll_id AND base_poll_id = 0 AND status = 4)

	return 0;



-- 에러

return 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkvalidbasepollid;
-- +goose StatementEnd
