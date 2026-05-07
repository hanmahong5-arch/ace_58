-- AionCore 5.8 — Sprint 1.1a batch 9 port: aion_SetFactionQuestAcquired (UPDATE).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetFactionQuestAcquired.sql
-- Original (T-SQL):
--   UPDATE user_faction_friendship
--      SET factionquest_curid           = @questId,
--          factionquest_curstate        = @questState,
--          factionquest_lastacquiredtime = @acquiredTime
--    WHERE char_id = @charId AND faction_id = @factionId
--
-- Translation notes:
--   * Pure UPDATE — no INSERT branch. T-SQL semantics: if the (char_id,
--     faction_id) row does not exist, no row is touched and the SP is a
--     no-op. Mirrors the AION game flow: a player must already be a
--     member of the faction (joined via aion_PutFactionFriendship,
--     ported as 00084) before they can have any faction quest progress.
--   * Three columns updated in one shot:
--       - factionquest_curid: current quest ID (0 = no active quest).
--       - factionquest_curstate: state machine cursor (kQuestStart /
--         kQuestStep / kQuestComplete — encoded as SMALLINT enum).
--       - factionquest_lastacquiredtime: UNIX seconds the quest was
--         last picked up; gates the "no faction quest more than once
--         per N hours" cooldown rule.
--   * The two unmodified factionquest columns
--     (factionquest_lastfinishedtime, factionquest_finishedcount) are
--     untouched — those are written by the *finish* path (a separate
--     SP not in this batch).
--   * Returns rows-affected so the caller can detect "no membership
--     row" (0) vs "progress committed" (1). 5.8 client uses 0 to
--     surface an error toast; 1 advances the quest UI.
--   * Schema (user_faction_friendship) created in 00072 pve_scaffold_round5;
--     all factionquest_* columns already present.
--
-- Used by:
--   scripts/handlers/cm_quest_action.lua    -- on faction quest acquisition
--   scripts/lib/faction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionquestacquired(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfactionquestacquired(
    _char_id       INTEGER,
    _faction_id    SMALLINT,
    _quest_id      INTEGER,
    _quest_state   SMALLINT,
    _acquired_time INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE user_faction_friendship
       SET factionquest_curid            = _quest_id,
           factionquest_curstate         = _quest_state,
           factionquest_lastacquiredtime = _acquired_time
     WHERE char_id    = _char_id
       AND faction_id = _faction_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionquestacquired(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd
