-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_QueryFrom.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_queryfrom(_before_sec INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;

	

	DECLARE _from_check_time DATETIME

	_from_check_time := DATEADD(S, -_before_sec, NOW())	



	SELECT TOP(50) p.name AS [SP Name],qs.execution_count,qs.last_execution_time,qs.last_elapsed_time,

	 qs.total_elapsed_time/qs.execution_count AS avg_elapsed_time

	FROM sys.procedures AS p

	INNER JOIN sys.dm_exec_procedure_stats AS qs

	ON p.object_id = qs.object_id

	WHERE qs.database_id = DB_ID()

	and DATEADD(S, (last_elapsed_time/1000000), Last_EXECUTION_TIME) > _from_check_time

	ORDER BY last_elapsed_time  DESC



	/*

	SELECT creation_time, last_execution_time, execution_count, total_worker_time, last_worker_time, min_worker_time, max_worker_time, total_elapsed_time, last_elapsed_time, min_elapsed_time, max_elapsed_time, dbid, 

					--text, 

					substring(text, (statement_start_offset / 2) + 1, ((case statement_end_offset when -1 then datalength(text) else statement_end_offset end - statement_start_offset)/2) + 1) as 'StatementQuery',

					COALESCE(object_name(objectid, dbid), 'unknown') as 'OBJName'

	from sys.dm_exec_query_stats qs cross apply sys.dm_exec_sql_text(qs.plan_handle)st

			join sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle

	where DATEADD(S, (last_elapsed_time/1000), last_execution_time) >= _from_check_time

	-- and text like '%delete%'

	*/




END /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_queryfrom;
-- +goose StatementEnd
