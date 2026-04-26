-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetFactionFriendshipList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetFactionFriendshipList.sql
--
-- Returns all faction friendship rows for a character, including the 5
-- factionquest_* bookkeeping columns.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfactionfriendshiplist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getfactionfriendshiplist(
    _char_id INTEGER
)
RETURNS TABLE (
    out_faction_id                    SMALLINT,
    out_friendship                    INTEGER,
    out_jointime                      INTEGER,
    out_factionquest_curid            INTEGER,
    out_factionquest_curstate         SMALLINT,
    out_factionquest_lastacquiredtime INTEGER,
    out_factionquest_lastfinishedtime INTEGER,
    out_factionquest_finishedcount    INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT faction_id, friendship, jointime,
           factionquest_curid, factionquest_curstate,
           factionquest_lastacquiredtime, factionquest_lastfinishedtime,
           factionquest_finishedcount
      FROM user_faction_friendship
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfactionfriendshiplist(INTEGER);
-- +goose StatementEnd
