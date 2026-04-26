-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailGetBoxSize.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailgetboxsize(_user_id INTEGER, _now_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _total	int

declare _unread	int

declare _unreadexpress	int

declare _unreadcashmail int



SELECT count(*) INTO _total from user_mail where to_id = _user_id and arrive_time <= _now_time 

select _unread = count(*) from user_mail where to_id = _user_id and state = 0 and arrive_time <= _now_time 

select _unreadexpress = count(*) from user_mail where to_id = _user_id and state = 0 and express_mail > 0 and arrive_time <= _now_time 

select _unreadcashmail = count(*) from user_mail where to_id = _user_id and state = 0 and express_mail = 2 and arrive_time <= _now_time 



select _total, _unread, _unreadexpress, _unreadcashmail;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetboxsize;
-- +goose StatementEnd
