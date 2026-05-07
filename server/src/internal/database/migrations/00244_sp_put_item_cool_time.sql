-- AionCore 5.8 — Sprint 1.1a batch 22 port: aion_PutItemCoolTime
-- (write-side companion of 00166 GetItemCoolTime — single-row blob upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutItemCoolTime.sql
-- Original (T-SQL):
--   if exists (select char_id from user_item_cooltime(UPDLOCK)
--              where char_id = @char_id)
--       update user_item_cooltime
--          set cooltime_data_cnt = @cooltime_data_cnt, data = @data
--        where char_id = @char_id
--   else
--       insert user_item_cooltime(char_id, cooltime_data_cnt, data)
--       values (@char_id, @cooltime_data_cnt, @data)
--
-- Schema:
--   user_item_cooltime is the **single-row blob** companion to the per-row
--   user_combine_cooltime / user_skill_cooltime tables. Each char gets one
--   row that holds *all* item cooltimes packed into a NCSoft-proprietary
--   BYTEA blob (cooltime_data_cnt = tuple count). The PG table was created
--   in 00166 (GetItemCoolTime) — we DO NOT re-create it here, mirroring how
--   00224 / 00225 (auction_filter writes) reuse the read-side schema.
--
-- Translation notes:
--   * T-SQL EXISTS-UPDATE-or-INSERT under UPDLOCK lock hint → PG INSERT…
--     ON CONFLICT (char_id) DO UPDATE. Atomic on the PK; under PG's MVCC
--     this delivers the same race-free upsert semantics that NCSoft buys
--     with UPDLOCK in SQL Server (no torn reads, no double insert).
--   * varbinary(1024) → BYTEA. PG BYTEA is unbounded; the 1024-byte ceiling
--     is enforced by NCSoft client code (SP layer never validated it).
--     Pinned: no length CHECK in PG.
--   * smallint → SMALLINT (PG SMALLINT is 16-bit, signed; NCSoft smallint
--     is also 16-bit, signed). Width-equivalent.
--   * VOID return: T-SQL EXISTS-UPDATE-or-INSERT body has no SELECT or
--     RETURN — caller does not branch on inserted-vs-updated.
--
-- Bug-for-bug:
--   * @cooltime_data_cnt is provided by the caller and is NOT cross-checked
--     against the actual number of tuples decoded from @data. NCSoft trusts
--     the client; if it ships a count that disagrees with the blob, the
--     login-time hydrator may read past end. Pinned.
--   * No FK on char_id. An item-cooltime row can outlive its char (orphan).
--     Pinned (matches every other user_* table in this dump).
--
-- Used by:
--   scripts/handlers/cm_logout.lua            -- flush item cooltime on disconnect
--   scripts/handlers/cm_quit.lua              -- explicit save-on-quit path
--   scripts/lib/item_cooltime.lua             -- shared mutation helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitemcooltime(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id            : owning char_id (PK on user_item_cooltime)
-- _cooltime_data_cnt  : tuple count packed in _data (caller-trusted; not validated)
-- _data               : NCSoft-proprietary packed (item_id, expire_ms) blob
CREATE OR REPLACE FUNCTION aion_putitemcooltime(
    _char_id           INTEGER,
    _cooltime_data_cnt SMALLINT,
    _data              BYTEA
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_item_cooltime (char_id, cooltime_data_cnt, data)
    VALUES (_char_id, _cooltime_data_cnt, _data)
    ON CONFLICT (char_id) DO UPDATE SET
        cooltime_data_cnt = EXCLUDED.cooltime_data_cnt,
        data              = EXCLUDED.data;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitemcooltime(INTEGER, SMALLINT, BYTEA);
-- +goose StatementEnd
