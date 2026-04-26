-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: usp_trace_start.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION usp_trace_start(_trace_file_name TEXT, _trace_name TEXT, _option INTEGER, _max_file_size BIGINT, _stop_time TIMESTAMPTZ, _events TEXT, _cols TEXT, _include_filter TEXT, _exclude_filter TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


 

                  -- 사용자변수선언

                  DECLARE _trace_i_d int

                  DECLARE _on bit

                  DECLARE _rc int

                  

                  _on := 1

                  

                  -- 이벤트와이벤트열을확인한다.

                  IF _events IS NULL OR _cols IS NULL BEGIN
RAISE NOTICE '%', 'No Events or Coloumns.';

                                   RETURN -1

                  END

                  

                  -- 파일경로와파일명을설정

                  IF _trace_file_name IS NULL 

                                   SELECT 'C:\Trace\Trace' + CONVERT(char(8),NOW(), 112)

                                   --SELECT _trace_file_name = 'C:\Trace\Trace_' + CONVERT(char(8),NOW(), 112)

                                   

                  -- 추척큐를만든다.

                  EXEC _rc = sp_trace_create _trace_i_d out, _option, _trace_file_name, _max_file_size, _stop_time

                  IF _rc <> 0 BEGIN
RAISE NOTICE '%', 'Trace not started' INTO _trace_file_name;

                                             RETURN _rc

                  END
RAISE NOTICE '%', 'Trace started.';
RAISE NOTICE '%', 'The trace file name is ' + _trace_file_name +'.';

                  

                  -- 추척할이벤트클래스들과이벤트열들을지정한다.

                  DECLARE _i int, _j int, _event int, _col int, _colstring varchar(300)

                  

                  IF RIGHT(_events, 1) <> ',' _events := _events + ','

                  _i := charindex(',', _events)

                  WHILE _i <> 0 BEGIN

                                            _event := cast(LEFT(_events, _i - 1) AS int)

                                            _colstring := _cols

                                            

                                            IF RIGHT(_colstring, 1) <> ',' _colstring := _colstring + ','

                                            _j := charindex(',', _colstring)

                                            

                                            WHILE _j <> 0 BEGIN

                                                       _col := CAST(LEFT(_colstring,_j-1) AS int)

                                                       EXEC sp_trace_setevent _trace_i_d, _event, _col, _on

                                                       _colstring := SUBSTRING(_colstring, _j+1, 300)

                                                       _j := CHARINDEX(',', _colstring)

                                            END

                                            _events := substring(_events, _i + 1, 300)

                                            _i := charindex(',', _events)

                  END

                  

                  -- 필터를설정한다.

                  EXEC sp_trace_setfilter _trace_i_d, 10, 0, 7, N'SQL Profiler'

                  EXEC sp_trace_setfilter _trace_i_d, 1, 0, 7, N'EXEC% sp_%trace%'

                  

                  IF _include_filter IS NOT NULL

                                   EXEC sp_trace_setfilter _trace_i_d, 1, 0, 6, _include_filter

                                   

                  IF _exclude_filter IS NOT NULL

                                   EXEC sp_trace_setfilter _trace_i_d, 1, 0, 7, _exclude_filter

                                   

                  -- 추척을활성화한다.

                  EXEC sp_trace_setstatus _trace_i_d, 1

                  

                  -- 추척을기록한다. (TempDB의테이블생성사용)

                  -- 기록하는이유는Trace Stop 시TraceID를알아야하기때문

                  IF object_id('tempdb..TraceQueueList') IS NULL BEGIN 

                                   CREATE TABLE tempdb..TraceQueueList(TraceID int, TraceName varchar(20), TraceFile sysname)

                  END

                  

                  IF EXISTS(SELECT * FROM tempdb..TraceQueueList WHERE TraceName = _trace_name) BEGIN

                                   UPDATE temdb..TraceQueueList SET TraceID = _trace_id, TraceFile = _trace_file_name

                                   WHERE TraceName = _trace_name

                  END ELSE BEGIN

                                   INSERT tempdb..TraceQueueList VALUES (_trace_i_d, _trace_name, _trace_file_name)

                  END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS usp_trace_start;
-- +goose StatementEnd
