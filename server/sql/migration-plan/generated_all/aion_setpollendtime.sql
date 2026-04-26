-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPollEndTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpollendtime(_poll_id INTEGER, _end_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update poll_info

set  end_time = _end_time

where poll_id = _poll_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpollendtime;
-- +goose StatementEnd
