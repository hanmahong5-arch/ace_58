-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetMoveCharStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmovecharstatus(_temp INTEGER, _temp1 INTEGER, _temp2 INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	-- 사용안할 sp인데 개발망 빌드 버전에 들어가버려서 임시로 넣어둠



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmovecharstatus;
-- +goose StatementEnd
