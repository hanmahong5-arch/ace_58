-- AionCore 5.8 — Sprint 1.1a batch 13 port: aion_PutClientQuickBar (hotbar UPSERT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutClientQuickBar.sql
-- Original (T-SQL):
--   if exists (select char_id from user_client_quickbar(UPDLOCK) where char_id=@char_id)
--       update user_client_quickbar set data_size=@data_size, data=@data where char_id=@char_id
--   else
--       insert user_client_quickbar(char_id, data_size, data) values (@char_id, @data_size, @data)
--
-- Translation notes:
--   * Per-char 1:1 row of opaque hotbar config (slot id → skill/item id mapping).
--     The blob structure is parsed client-side; the server is a pure write-
--     through cache for it (same model as user_client_settings 00154/00155).
--   * Round 5 scaffold (00160) created `user_client_quickbar` with PK on
--     `char_id` and BYTEA `data`. UPSERT on PK is the natural translation.
--   * `data_size` is `smallint` in T-SQL (max 32767 bytes — but the actual
--     varbinary upper bound is 7168 in the source signature). PG SMALLINT
--     covers it identically.
--   * `data` is `varbinary(7168)` → BYTEA (no PG length cap; gateway enforces
--     the 7168-byte ceiling on the wire). 7168 = 32 slots * 224-byte slot
--     blob in 5.8 — one master bar plus the spare bars unlocked at L65.
--   * Returns rows-affected (always 1; UPSERT touches exactly one row).
--   * The IF EXISTS / UPDATE / ELSE INSERT pattern is identical to PutEmotion
--     above and 00075 PutHouseObject below. We use ON CONFLICT (char_id)
--     DO UPDATE which is byte-for-byte equivalent and atomic without UPDLOCK.
--
-- Used by:
--   scripts/handlers/cm_quickbar_set.lua     -- on hotbar drag/drop
--   scripts/handlers/cm_logout.lua           -- save on disconnect
--   scripts/lib/quickbar.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putclientquickbar(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putclientquickbar(
    _char_id    INTEGER,
    _data_size  SMALLINT,
    _data       BYTEA
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on the existing PK. Matches NCSoft IF EXISTS / UPDATE / ELSE
    -- INSERT semantics atomically. Both branches yield ROW_COUNT = 1.
    INSERT INTO user_client_quickbar (char_id, data_size, data)
    VALUES (_char_id, _data_size, _data)
    ON CONFLICT (char_id) DO UPDATE
       SET data_size = EXCLUDED.data_size,
           data      = EXCLUDED.data;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putclientquickbar(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd
