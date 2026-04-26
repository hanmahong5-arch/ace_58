-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_MailRead.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailRead.sql
-- Returns the body of one mail and (atomically) marks it read.
-- T-SQL: SELECT then conditional UPDATE in same SP. We replicate by running
-- the UPDATE first inside a CTE so we have a single round-trip and avoid
-- the read-then-write race window. The function returns the mail body.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailread(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailread(_char_id INTEGER, _mail_id BIGINT)
RETURNS TABLE (
    to_id         INTEGER,
    from_id       INTEGER,
    from_name     TEXT,
    title         TEXT,
    content       TEXT,
    item_id       BIGINT,
    item_nameid   INTEGER,
    item_amount   BIGINT,
    money         BIGINT,
    abyss_point   BIGINT,
    state         SMALLINT,
    arrive_time   INTEGER,
    express_mail  INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Mark read first if it's the recipient and currently unread.
    -- Qualify with the table name so RETURNS TABLE parameter names
    -- (to_id, state, …) don't collide with column refs.
    UPDATE user_mail um
       SET state = 1
     WHERE um.id = _mail_id AND um.to_id = _char_id AND um.state = 0;

    RETURN QUERY
        SELECT um.to_id, um.from_id, um.from_name, um.title, um.content,
               um.item_id, um.item_nameid, um.item_amount, um.money,
               um.abyss_point, um.state, um.arrive_time, um.express_mail
          FROM user_mail um
         WHERE um.id = _mail_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailread(INTEGER, BIGINT);
-- +goose StatementEnd
