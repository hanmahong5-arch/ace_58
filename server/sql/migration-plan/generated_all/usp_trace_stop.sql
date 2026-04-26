-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: usp_trace_stop.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION usp_trace_stop(_trace_name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


                  

                  -- 변수선언

                  DECLARE _trace_i_d int

                  DECLARE _trace_file_name sysname

                  

                  -- 추적목록을확인하여, 추적을중지한다.

                  IF object_id('tempdb..TraceQueueList') IS NOT NULL BEGIN

                                   SELECT TraceID, _trace_file_name = TraceFile INTO _trace_i_d FROM tempdb..TraceQueueList

                                   WHERE TraceName = _trace_name

                                                     IF @_rowcount <> 0 BEGIN

                                                                       EXEC sp_trace_setstatus _trace_i_d, 0

                                                                       EXEC sp_trace_setstatus _trace_i_d, 2

 

                                                                       DELETE FROM tempdb..TraceQueueList WHERE TraceName = _trace_name
RAISE NOTICE '%', 'Trace is stopped.' + ' The trace output file name is ' + _trace_file_name;

                                                     END

                  END ELSE BEGIN
RAISE NOTICE '%', 'No active traces.';

                  END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS usp_trace_stop;
-- +goose StatementEnd
