-- AionCore 5.8 — Sprint 1.1a batch 11 port: aion_AddWorldBotChannelInfo.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddWorldBotChannelInfo.sql
-- Original (T-SQL):
--   if EXISTS(SELECT char_id FROM world_bot_channel_info(updlock) WHERE char_id = @nCharId)
--   begin
--       UPDATE world_bot_channel_info SET world_id = @WorldId WHERE char_id = @nCharId
--   end
--   INSERT world_bot_channel_info (char_id, account_id, world_id) VALUES (@nCharId, @nAccountId, @WorldId)
--
-- Translation notes:
--   * `world_bot_channel_info` tracks which world (channel) a character's
--     world-bot (NCSoft term for the broadcast NPC chat / global channel
--     manager) is currently bound to. One char can be in only ONE channel
--     at a time, but the schema is flat — no PK constraint, no UNIQUE.
--   * The T-SQL has a **structural NCSoft bug**: the IF EXISTS branch
--     UPDATEs the existing row, but the INSERT runs UNCONDITIONALLY
--     (it's NOT inside an else). So:
--       - first call (no row): INSERT only → 1 row.
--       - second call (row exists): UPDATE existing row + INSERT a new
--         row → 2 rows for the same char_id, both with world_id set to
--         the latest call.
--     This compounds: N calls for same char produces N rows. Production
--     side-effects: read paths (`SELECT * WHERE char_id=...`) get a
--     fan-out and the consumer DISTINCTs / TOP 1's on read.
--   * We mirror the bug-for-bug T-SQL semantics here. If the gameplay
--     team wants idempotence, the FIX is at the SP level (drop the bare
--     INSERT, wrap in IF/ELSE) plus a UNIQUE(char_id) constraint and a
--     one-shot data clean. Don't unilaterally diverge here — every read
--     path was written assuming the fan-out shape.
--   * `(updlock)` hint is T-SQL row-lock-during-read; PG analog is
--     `SELECT ... FOR UPDATE`. We replicate via an explicit advisory
--     check-then-write, but functionally PG's READ COMMITTED + the
--     SELECT-EXISTS pattern races identically to the T-SQL version
--     (NCSoft lived with that race). Acceptable parity.
--   * Returns rows-affected (count of rows the FINAL INSERT inserted,
--     always 1) so the caller can sanity-check the round-trip. UPDATE
--     count is intentionally NOT returned (matches T-SQL VOID return
--     character, GMs don't need to know the dup count).
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua    -- on world entry, register channel
--   scripts/handlers/cm_change_channel.lua -- channel switch flow
--   scripts/lib/world_bot.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- world_bot_channel_info — per-character channel binding for the
-- world-bot global broadcaster. NO unique constraint on char_id —
-- T-SQL allows fan-out duplicates (see translation notes above).
-- ====================================================================
CREATE TABLE IF NOT EXISTS world_bot_channel_info (
    char_id    INTEGER NOT NULL,
    account_id INTEGER NOT NULL,
    world_id   INTEGER NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_world_bot_channel_char ON world_bot_channel_info(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addworldbotchannelinfo(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addworldbotchannelinfo(
    _char_id    INTEGER,
    _account_id INTEGER,
    _world_id   INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Bug-for-bug NCSoft: IF row exists, update it; THEN unconditionally
    -- INSERT a new row. Compounds duplicates on repeated calls.
    IF EXISTS (SELECT 1 FROM world_bot_channel_info WHERE char_id = _char_id FOR UPDATE) THEN
        UPDATE world_bot_channel_info
           SET world_id = _world_id
         WHERE char_id  = _char_id;
    END IF;

    INSERT INTO world_bot_channel_info (char_id, account_id, world_id)
    VALUES (_char_id, _account_id, _world_id);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addworldbotchannelinfo(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_world_bot_channel_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS world_bot_channel_info;
-- +goose StatementEnd
