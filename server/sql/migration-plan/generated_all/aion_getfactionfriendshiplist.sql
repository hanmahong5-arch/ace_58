-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetFactionFriendshipList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getfactionfriendshiplist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT faction_id,friendship,jointime,factionquest_curid,factionquest_curstate,factionquest_lastacquiredtime,factionquest_lastfinishedtime,factionquest_finishedcount

FROM user_faction_friendship

WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfactionfriendshiplist;
-- +goose StatementEnd
