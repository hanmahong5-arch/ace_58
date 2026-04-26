-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPollStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpollstatus(_poll_id INTEGER, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update poll_info

set status = _status

where poll_id = _poll_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpollstatus;
-- +goose StatementEnd
