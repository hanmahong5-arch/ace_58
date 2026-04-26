-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_GetItemList_20120102.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetItemList_20120102.sql
-- Returns the inventory of @char_id, scoped to one warehouse partition
-- (0 = inventory, 1 = char warehouse, 2 = account warehouse, …) and
-- excluding rows already exported (export_id != 0 means item is in transit
-- to another server). Round 5's aion_GetItem returns ONE item by id; this SP
-- returns the bulk list, used by enter-world / inventory-refresh paths.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlist_20120102(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemlist_20120102(
    _char_id   INTEGER,
    _warehouse INTEGER
)
RETURNS TABLE (
    id            BIGINT,
    name_id       INTEGER,
    slot_id       INTEGER,
    amount        BIGINT,
    tid           BIGINT,
    slot          INTEGER,
    producer      TEXT,
    expired_time  INTEGER,
    buy_amount    INTEGER,
    buy_duration  INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT ui.id, ui.name_id, ui.slot_id, ui.amount, ui.tid, ui.slot,
               ui.producer, ui.expired_time, ui.buy_amount, ui.buy_duration
          FROM user_item ui
         WHERE ui.char_id   = _char_id
           AND ui.warehouse = _warehouse
           AND ui.export_id = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemlist_20120102(INTEGER, INTEGER);
-- +goose StatementEnd
