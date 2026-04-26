-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_InitInstanceCooltime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_initinstancecooltime()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	--DELETE FROM user_instance WHERE count_variate <= 0 and world_id not in (302400000) -- 도전의 탑만 예외처리.

	DELETE FROM user_instance WHERE reentrance_time < (GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) - 8 * 3600)

	--TRUNCATE TABLE user_instance


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_initinstancecooltime;
-- +goose StatementEnd
