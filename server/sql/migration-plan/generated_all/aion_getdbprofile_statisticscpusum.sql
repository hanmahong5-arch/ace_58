-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_StatisticsCpuSum.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_statisticscpusum()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;



	SELECT sum(qs.total_worker_time) as total_cpu_time_sum,

	sum(qs.execution_count) as total_execution_count_sum,

	count(*) as '#_statements',

	0, --qt.dbid, 

	qt.text, 

	COALESCE(object_name(objectid, dbid), 'unknown') as 'OBJName'

	FROM sys.dm_exec_query_stats as qs

	CROSS APPLY sys.dm_exec_sql_text (qs.sql_handle) as qt

	GROUP BY qt.dbid,qt.objectid, qs.sql_handle,qt.text

	ORDER BY sum(qs.total_worker_time) DESC,qs.sql_handle /* LIMIT 10 appended */ LIMIT 10;




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_statisticscpusum;
-- +goose StatementEnd
