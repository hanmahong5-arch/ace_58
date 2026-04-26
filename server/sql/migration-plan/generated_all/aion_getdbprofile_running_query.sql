-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_RUNNING_QUERY.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_running_query()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;



    -- Insert statements for procedure here

	SELECT a.session_id, a.host_name, a.client_interface_name, a.login_name, a.status, a.last_request_start_time

	,       b.start_time, b.status, b.command, db_name(c.dbid) as 'DBName', object_name(c.objectid, c.dbid) as 'OBJName', b.last_wait_type, b.wait_time

	,       b.cpu_time, b.total_elapsed_time, b.reads, b.writes, b.logical_reads

	,       substring(c.text, (b.statement_start_offset / 2) + 1, ((case b.statement_end_offset when -1 then datalength(c.text) else b.statement_end_offset end - b.statement_start_offset)/2) + 1) as 'StatementQuery'

	,       d.query_plan

	,		b.statement_end_offset

	from               sys.dm_exec_sessions a

		inner join     sys.dm_exec_requests b on a.session_id = b.session_id

		cross apply   sys.dm_exec_sql_text(b.sql_handle) c

		cross apply   sys.dm_exec_text_query_plan(b.plan_handle, b.statement_start_offset, b.statement_end_offset) d

	where a.session_id > 50 and a.last_request_start_time > a.last_request_end_time

	order by a.last_request_start_time, a.session_id

	


END /* LIMIT 30 appended */ LIMIT 30;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_running_query;
-- +goose StatementEnd
