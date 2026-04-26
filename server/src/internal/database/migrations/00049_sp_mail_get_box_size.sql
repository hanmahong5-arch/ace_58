-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_MailGetBoxSize.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailGetBoxSize.sql
-- Returns 4 counts in one row: (total, unread, unread_express, unread_cashmail).
-- Cashmail = express_mail = 2 by NCSoft convention; express_mail > 0 covers
-- both express and cashmail.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetboxsize(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailgetboxsize(_user_id INTEGER, _now_time INTEGER)
RETURNS TABLE (
    total            INTEGER,
    unread           INTEGER,
    unread_express   INTEGER,
    unread_cashmail  INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Aggregate filter clauses must be AGG(...) FILTER then cast.
    RETURN QUERY
        SELECT
            (COUNT(*))::INTEGER                                                                              AS total,
            (COUNT(*) FILTER (WHERE state = 0))::INTEGER                                                     AS unread,
            (COUNT(*) FILTER (WHERE state = 0 AND express_mail > 0))::INTEGER                                AS unread_express,
            (COUNT(*) FILTER (WHERE state = 0 AND express_mail = 2))::INTEGER                                AS unread_cashmail
          FROM user_mail
         WHERE to_id = _user_id
           AND arrive_time <= _now_time
           AND delete_flag = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetboxsize(INTEGER, INTEGER);
-- +goose StatementEnd
