-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFactionQuestAcquired.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfactionquestacquired(_char_id INTEGER, _faction_id INTEGER, _quest_id INTEGER, _quest_state INTEGER, _acquired_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	UPDATE user_faction_friendship 

	SET factionquest_curid = _quest_id, factionquest_curstate = _quest_state, factionquest_lastacquiredtime = _acquired_time

	WHERE char_id = _char_id AND faction_id = _faction_id	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionquestacquired;
-- +goose StatementEnd
