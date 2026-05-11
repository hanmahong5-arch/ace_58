-- AionCore 5.8 — Sprint 1.1a Round 13: aion_MailWrite_20160804.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailWrite_20160804.sql
--
-- 玩家→玩家邮件写入。系统邮件（补偿/活动）走 00031 aion_mailwritesys_20111227。
-- 本 SP 与系统邮件的差异：
--   * 物品过户带 from_id 校验（防止伪造发件人偷取他人物品）；
--   * 同步更新 user_item_option 的 char_id；
--   * 保留 abyss_point 字段（系统版 00031 无该列，玩家邮件可附 AP）。
--
-- 本端返回 BIGINT mail_id 供 lib/mail.lua 推送 SM_MAIL_NEW（NCSoft 原版无返回，
-- 但 PG SERIAL/IDENTITY RETURNING 是免费的，提升一侧设计无损耗）。

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailwrite_20160804(
    INTEGER, TEXT, INTEGER, TEXT, TEXT, TEXT,
    BIGINT, INTEGER, BIGINT, BIGINT, BIGINT, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailwrite_20160804(
    _to_id          INTEGER,
    _to_name        TEXT,
    _from_id        INTEGER,
    _from_name      TEXT,
    _title          TEXT,
    _content        TEXT,
    _item_id        BIGINT,
    _item_nameid    INTEGER,
    _item_amount    BIGINT,
    _money          BIGINT,
    _abyss_point    BIGINT,
    _warehouse      INTEGER,
    _arrive_time    INTEGER,
    _express_mail   INTEGER
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new_id BIGINT;
BEGIN
    -- 物品过户：必须 char_id 当前等于 from_id（防伪造）。option 表同步。
    IF _item_id <> 0 THEN
        UPDATE user_item
           SET warehouse = _warehouse,
               char_id   = _to_id
         WHERE id = _item_id AND char_id = _from_id;
        UPDATE user_item_option
           SET char_id = _to_id
         WHERE id = _item_id AND char_id = _from_id;
    END IF;

    INSERT INTO user_mail (
        to_id, to_name, from_id, from_name, title, content,
        item_id, item_nameid, item_amount,
        money, abyss_point, arrive_time, express_mail
    ) VALUES (
        _to_id, _to_name, _from_id, _from_name, _title, _content,
        _item_id, _item_nameid, _item_amount,
        _money, _abyss_point, _arrive_time, _express_mail
    )
    RETURNING id INTO _new_id;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailwrite_20160804(
    INTEGER, TEXT, INTEGER, TEXT, TEXT, TEXT,
    BIGINT, INTEGER, BIGINT, BIGINT, BIGINT, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd
