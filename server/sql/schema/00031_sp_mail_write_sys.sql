-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_MailWriteSys_20111227.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailWriteSys_20111227.sql
-- Writes a system mail (compensation, event reward, quest reward).
-- If item_id <> 0 the attached item's char_id and warehouse flag are updated
-- so it ends up in the recipient's mail-attachment view.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailwritesys_20111227(
    INTEGER, TEXT, INTEGER, TEXT, TEXT, TEXT,
    BIGINT, INTEGER, BIGINT, BIGINT, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailwritesys_20111227(
    _to_id        INTEGER,
    _to_name      TEXT,
    _from_id      INTEGER,
    _from_name    TEXT,
    _title        TEXT,
    _content      TEXT,
    _item_id      BIGINT,
    _item_nameid  INTEGER,
    _item_amount  BIGINT,
    _money        BIGINT,
    _warehouse    INTEGER,
    _arrive_time  INTEGER,
    _express_mail INTEGER
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new_id BIGINT;
BEGIN
    IF _item_id <> 0 THEN
        UPDATE user_item        SET warehouse = _warehouse, char_id = _to_id WHERE id = _item_id;
        UPDATE user_item_option SET char_id   = _to_id                       WHERE id = _item_id;
    END IF;

    INSERT INTO user_mail (
        to_id, to_name, from_id, from_name, title, content,
        item_id, item_nameid, item_amount, money, arrive_time, express_mail
    ) VALUES (
        _to_id, _to_name, _from_id, _from_name, _title, _content,
        _item_id, _item_nameid, _item_amount, _money, _arrive_time, _express_mail
    )
    RETURNING id INTO _new_id;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailwritesys_20111227(
    INTEGER, TEXT, INTEGER, TEXT, TEXT, TEXT,
    BIGINT, INTEGER, BIGINT, BIGINT, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd
