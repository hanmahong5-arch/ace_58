-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_StatisticsIoTotal.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_statisticsiototal()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;



	SELECT (total_logical_reads/execution_count) as avg_logical_reads

	 , (total_logical_writes/execution_count) as avg_logical_writes

	 , (total_physical_reads/execution_count) as avg_physical_reads

	 , Execution_count

	 , statement_start_offset

	 , COALESCE(q.text, 'UNKNOWN')

	 , COALESCE(object_name(q.objectid, q.dbid),'UNKNOWN')  as 'OBJName'

	from sys.dm_exec_query_stats

		  cross apply sys.dm_exec_query_plan(plan_handle) p

		  cross apply sys.dm_exec_sql_text(plan_handle) as q

	order by (total_logical_reads + total_logical_writes)/execution_count Desc




END /* LIMIT 10 appended */ LIMIT 10;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_statisticsiototal;
-- +goose StatementEnd
