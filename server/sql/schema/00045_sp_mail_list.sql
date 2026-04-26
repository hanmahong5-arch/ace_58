-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_MailList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailList.sql
-- Returns up to @maxMail mails for @char_id whose arrive_time has elapsed,
-- newest-first. T-SQL "TOP (@maxMail)" → PG "LIMIT _max_mail".

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maillist(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_maillist(
    _char_id   INTEGER,
    _now_time  INTEGER,
    _max_mail  INTEGER
)
RETURNS TABLE (
    id            BIGINT,
    from_name     TEXT,
    title         TEXT,
    state         SMALLINT,
    arrive_time   INTEGER,
    item_id       BIGINT,
    money         BIGINT,
    abyss_point   BIGINT,
    express_mail  INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT um.id, um.from_name, um.title, um.state,
               um.arrive_time, um.item_id, um.money, um.abyss_point, um.express_mail
          FROM user_mail um
         WHERE um.to_id = _char_id
           AND um.arrive_time <= _now_time
           AND um.delete_flag = 0
         ORDER BY um.arrive_time DESC
         LIMIT _max_mail;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maillist(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
