-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetItem.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetItem.sql
-- Returns one row of full item state (inventory + option + enchant proba).
-- LEFT JOIN user_item_option so items without option rows still load.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitem(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitem(_user_item_dbid BIGINT)
RETURNS TABLE (
    id                     BIGINT,
    name_id                INTEGER,
    slot_id                INTEGER,
    amount                 BIGINT,
    tid                    BIGINT,
    slot                   INTEGER,
    soul_bound             INTEGER,
    enchant_count          INTEGER,
    skin_name_id           INTEGER,
    stat_enchant_name0     INTEGER,
    stat_enchant_name1     INTEGER,
    stat_enchant_name2     INTEGER,
    stat_enchant_name3     INTEGER,
    stat_enchant_name4     INTEGER,
    stat_enchant_name5     INTEGER,
    option_count           INTEGER,
    dye_info               INTEGER,
    proc_tool_nameid       INTEGER,
    producer               TEXT,
    expired_time           INTEGER,
    buy_amount             INTEGER,
    buy_duration           INTEGER,
    obtain_skin_type       INTEGER,
    expire_skin_time       INTEGER,
    expire_dye_time        INTEGER,
    random_option          INTEGER,
    limit_enchant_count    INTEGER,
    reidentify_count       INTEGER,
    authorize_count        INTEGER,
    vanish_point           INTEGER,
    enchant_prob_addition  INTEGER,
    option_prob_addition   INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.name_id, a.slot_id, a.amount, a.tid, a.slot,
           COALESCE(b.soul_bound, 0), COALESCE(b.enchant_count, 0),
           COALESCE(b.skin_name_id, 0),
           COALESCE(b.stat_enchant_name0, 0), COALESCE(b.stat_enchant_name1, 0),
           COALESCE(b.stat_enchant_name2, 0), COALESCE(b.stat_enchant_name3, 0),
           COALESCE(b.stat_enchant_name4, 0), COALESCE(b.stat_enchant_name5, 0),
           COALESCE(b.option_count, 0),
           COALESCE(b.dye_info, 0), COALESCE(b.proc_tool_nameid, 0),
           a.producer, a.expired_time, a.buy_amount, a.buy_duration,
           COALESCE(b.obtain_skin_type, 0), COALESCE(b.expire_skin_time, 0),
           COALESCE(b.expire_dye_time, 0),
           COALESCE(b.random_option, 0),
           COALESCE(b.limit_enchant_count, 0),
           COALESCE(b.reidentify_count, 0),
           COALESCE(b.authorize_count, 0),
           COALESCE(b.vanish_point, 0),
           COALESCE(b.enchant_prob_addition, 0),
           COALESCE(b.option_prob_addition, 0)
      FROM user_item a
      LEFT JOIN user_item_option b ON a.id = b.id
     WHERE a.id = _user_item_dbid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitem(BIGINT);
-- +goose StatementEnd
