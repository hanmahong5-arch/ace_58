-- AionCore 5.8 — Sprint 1.1a Round 13: aion_SetItemWarehouse_20111227.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetItemWarehouse_20111227.sql
--
-- 把一件 user_item 切换 warehouse 分区 + 改 owner（用于跨号转移）。
-- NCSoft 用同一个 SP 实现：
--   * 玩家仓库存取（deposit/withdraw）→ warehouse 0↔2 同 owner
--   * 跨账号转移（auction 成交、mail 附件领取）→ warehouse + owner 同时改
--
-- warehouse 编号约定（与 00037 aion_getitemlist_20120102 一致）：
--   0 = inventory (cube)
--   1 = char warehouse (角色专属仓库)
--   2 = account warehouse (账号共享仓库)
--   …
--
-- 同步更新 user_item_option.char_id（NCSoft 的 schema 把 enchant/random_attr 列
-- 拆到 user_item_option，update_date 由触发器自动刷新或本端手动 SET）。

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemwarehouse_20111227(BIGINT, SMALLINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemwarehouse_20111227(
    _id         BIGINT,
    _warehouse  SMALLINT,
    _owner_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_item
       SET warehouse = _warehouse,
           char_id   = _owner_id,
           update_date = NOW()
     WHERE id = _id;

    UPDATE user_item_option
       SET char_id = _owner_id
     WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemwarehouse_20111227(BIGINT, SMALLINT, INTEGER);
-- +goose StatementEnd
