-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailGetQueuedMailList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailgetqueuedmaillist(_char_id INTEGER, _now_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select arrive_time

from user_mail

where to_id = _char_id and arrive_time > _now_time 

order by arrive_time asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetqueuedmaillist;
-- +goose StatementEnd
