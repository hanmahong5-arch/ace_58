-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_PollAnswerDA_SrchPollRSByIDandDate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_pollanswerda_srchpollrsbyidanddate(_poll_id TEXT, _start_date TEXT, _end_date TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			select	poll_id,char_id,user_id, account_id, account_name, class, race, world, xlocation, ylocation, zlocation, lev, answer, convert(nvarchar, answer_time,20) answer_time 

			from	poll_answer(nolock)

			where	poll_id=_poll_id and answer_time >= ''+_start_date+'' and answer_time < ''+_end_date+'';
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_pollanswerda_srchpollrsbyidanddate;
-- +goose StatementEnd
