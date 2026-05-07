-- AionCore 5.8 — Sprint 1.1a batch 10 port: aion_SetFactionQuestFinished (UPDATE + counter).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFactionQuestFinished.sql
-- Original (T-SQL):
--   UPDATE user_faction_friendship
--      SET factionquest_curid            = @questId,
--          factionquest_curstate         = @questState,
--          factionquest_lastfinishedtime = @finishedTime,
--          factionquest_finishedcount    = factionquest_finishedcount + 1
--    WHERE char_id = @charId AND faction_id = @factionId
--
-- Translation notes:
--   * Direct mirror of 00183 (SetFactionQuestAcquired) on the **finish path**.
--     Same UPDATE shape, same row-not-found semantics, same return contract,
--     but writes a different column triplet plus a self-incrementing counter:
--       - factionquest_curid            ← _quest_id (typically 0 to mark
--         "no active quest" once the quest closes; client passes the value)
--       - factionquest_curstate         ← _quest_state (kQuestComplete /
--         kQuestStart back to idle, etc.)
--       - factionquest_lastfinishedtime ← _finished_time (UNIX seconds; gates
--         the per-faction "no finish more than once per N hours" cooldown)
--       - factionquest_finishedcount    ← finishedcount + 1 (counter for
--         daily/weekly/total faction-quest analytics; PG `column = column + 1`
--         is the canonical idiom — atomic at row level under READ COMMITTED,
--         so two concurrent finishes on the same row serialise via row lock
--         and BOTH increments are observable).
--   * The *acquired* triplet (factionquest_lastacquiredtime + the 2 cols
--     written by 00183) is intentionally **untouched** here — those belong
--     to the open phase. T-SQL semantics preserved.
--   * Pure UPDATE — no INSERT branch. If the (char_id, faction_id) row does
--     not exist (player not a faction member), no row is touched and the SP
--     is a no-op. Mirrors the AION game flow: a player must already be a
--     member (via 00084 PutFactionFriendship) before they can have any
--     factionquest progress to finish.
--   * Returns rows-affected so the caller can detect "no membership row" (0)
--     vs "finish committed" (1). 5.8 client uses 0 to surface an error
--     toast; 1 advances the quest UI.
--   * Schema (user_faction_friendship) created in 00072 pve_scaffold_round5;
--     all factionquest_* columns already present (verified at 00072 lines
--     117-121). Migration is order-independent.
--
-- Used by:
--   scripts/handlers/cm_quest_action.lua    -- on faction quest completion
--   scripts/lib/faction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionquestfinished(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfactionquestfinished(
    _char_id       INTEGER,
    _faction_id    SMALLINT,
    _quest_id      INTEGER,
    _quest_state   SMALLINT,
    _finished_time INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE user_faction_friendship
       SET factionquest_curid            = _quest_id,
           factionquest_curstate         = _quest_state,
           factionquest_lastfinishedtime = _finished_time,
           factionquest_finishedcount    = factionquest_finishedcount + 1
     WHERE char_id    = _char_id
       AND faction_id = _faction_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionquestfinished(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd
