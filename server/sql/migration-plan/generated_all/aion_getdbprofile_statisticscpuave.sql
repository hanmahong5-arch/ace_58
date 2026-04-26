-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_StatisticsCpuAve.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_statisticscpuave()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;



	SELECT [Average CPU used] = total_worker_time / qs.execution_count

	,[Total CPU used] = total_worker_time

	,[Last CPU used] = last_worker_time

	,[MAX CPU used] = max_worker_time

	,[Execution count] = qs.execution_count

	,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 

			 (CASE WHEN qs.statement_end_offset = -1 

				THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 

			  ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)

    , COALESCE(object_name(objectid, dbid), 'unknown') as 'OBJName'

	,qs.creation_time

	,qs.last_execution_time

	,qs.min_worker_time

	,qs.max_worker_time

	FROM sys.dm_exec_query_stats qs

	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt

	ORDER BY [Average CPU used] DESC




END /* LIMIT 10 appended */ LIMIT 10;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_statisticscpuave;
-- +goose StatementEnd
