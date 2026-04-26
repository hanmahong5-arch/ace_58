-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetDbProfile_BlockQuery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getdbprofile_blockquery()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	set transaction isolation level read uncommitted;





	--DMV Lock으로인해Block 된쿼리찾기/06/25 21:30 from MS-SQL DMV

	select   a.session_id as 'BlockedSessionID', b.blocking_session_id

	,        b.wait_duration_ms / 1000 as 'WaitDuration(Sec)', b.wait_type

	,        c.resource_type, db_name(c.resource_database_id) as 'ResourceDBName', c.request_mode, c.request_type, c.request_status, b.resource_description

	,        db_name(e.dbid) as 'BlockedDBName', object_name(e.objectid) as 'BlockedObjectName', e.text as 'BlockedQuery'

	,        substring(e.text, (d.statement_start_offset / 2) + 1, ((case d.statement_end_offset when -1 then datalength(e.text) else d.statement_end_offset end - d.statement_start_offset)/2) + 1) as 'BlockedStmt'

	,        db_name(g.dbid) as 'BlockingDBName', object_name(g.objectid) as 'BlockingObjectName', g.text as 'BlockingQuery'

	,        a.task_address, a.worker_address, b.waiting_task_address, b.blocking_task_address

	from            sys.dm_os_tasks a with(nolock)

		inner join  sys.dm_os_waiting_tasks b with(nolock)  on a.task_address = b.waiting_task_address or a.task_address = b.blocking_task_address

		inner join  sys.dm_tran_locks c with(nolock)        on b.resource_address = c.lock_owner_address

		inner join  sys.dm_exec_requests d with(nolock)     on a.session_id = d.session_id and a.request_id = d.request_id

		cross apply sys.dm_exec_sql_text(d.sql_handle) e

		inner join  sys.dm_exec_connections f               on b.blocking_session_id = f.session_id

		cross apply sys.dm_exec_sql_text(f.most_recent_sql_handle) g

	where b.blocking_session_id is not null

	--  and b.wait_duration_ms > 3000






END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getdbprofile_blockquery;
-- +goose StatementEnd
