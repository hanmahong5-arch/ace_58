-- AionCore 5.8 — Sprint 1.1a Round 13: aion_MailGetItem.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_MailGetItem.sql
--
-- 邮件附件领取（item / money / abyss_point 三类，分别由 flag=0/1/2 驱动）。
-- 一次调用只领一类；item 走 user_item.warehouse 转交（不删 item 行），money/ap
-- 走 user_mail 字段清零。返回 4 列：
--   rc           — 0=success / 1=invalid_key (mail not found) / 2=no_attached_asset
--   out_item_id  — 邮件当前的 item_id（pre-clear 值，便于 caller 知道 transferred 哪件）
--   out_money    — 邮件当前的 money
--   out_ap       — 邮件当前的 abyss_point
--
-- 与 NCSoft 行为差异：
--   * NCSoft 在 begin tran/rollback 包整个流程；PG plpgsql 函数本身在外层 tx 里
--     执行，调用方（lua → db.call）若需要原子性应该在更上层包 BEGIN/COMMIT。
--     由于函数内多个 UPDATE 都依赖前置 SELECT 的结果，PG 的语句级原子性已足够。
--   * 列名 `out_*` 前缀避免与 RETURNS TABLE 自动暴露的列与 PG 关键字冲突。

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetitem(INTEGER, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailgetitem(
    _char_id    INTEGER,
    _mail_id    BIGINT,
    _warehouse  INTEGER,
    _flag       INTEGER
)
RETURNS TABLE (
    rc           INTEGER,
    out_item_id  BIGINT,
    out_money    BIGINT,
    out_ap       BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_item_id BIGINT := 0;
    v_money   BIGINT := 0;
    v_ap      BIGINT := 0;
BEGIN
    -- 1) 锁行并取当前附件状态。to_id 必须等于 caller，防止越权领他人邮件。
    SELECT um.item_id, um.money, um.abyss_point
      INTO v_item_id, v_money, v_ap
      FROM user_mail um
     WHERE um.id = _mail_id AND um.to_id = _char_id
     FOR UPDATE;

    -- 2) 邮件不存在或不归 caller 所有 → rc=1。
    IF NOT FOUND THEN
        RETURN QUERY SELECT 1, 0::BIGINT, 0::BIGINT, 0::BIGINT;
        RETURN;
    END IF;

    -- 3) 按 flag 校验对应资产是否存在；不存在 → rc=2 + 当前快照。
    IF _flag = 0 AND v_item_id = 0 THEN
        RETURN QUERY SELECT 2, v_item_id, v_money, v_ap;
        RETURN;
    ELSIF _flag = 1 AND v_money = 0 THEN
        RETURN QUERY SELECT 2, v_item_id, v_money, v_ap;
        RETURN;
    ELSIF _flag = 2 AND v_ap = 0 THEN
        RETURN QUERY SELECT 2, v_item_id, v_money, v_ap;
        RETURN;
    END IF;

    -- 4) 实际领取：item 转移 warehouse 槽位 + 清邮件 item 字段；money/ap 清字段。
    IF _flag = 0 THEN
        UPDATE user_item
           SET warehouse = _warehouse
         WHERE id = v_item_id;
        UPDATE user_mail
           SET item_id = 0, item_nameid = 0, item_amount = 0
         WHERE id = _mail_id;
    ELSIF _flag = 1 THEN
        UPDATE user_mail
           SET money = 0
         WHERE id = _mail_id;
    ELSIF _flag = 2 THEN
        UPDATE user_mail
           SET abyss_point = 0
         WHERE id = _mail_id;
    ELSE
        -- flag 越界（非 0/1/2）— 静默返回快照而不修改，避免 SP 误用造成数据漂移。
        RETURN QUERY SELECT 2, v_item_id, v_money, v_ap;
        RETURN;
    END IF;

    -- 5) 成功，回报 pre-clear 快照（caller 据此 player.add_item / add_kinah）。
    RETURN QUERY SELECT 0, v_item_id, v_money, v_ap;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailgetitem(INTEGER, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd
