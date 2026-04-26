-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CleanInactiveOverseasEventQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_cleaninactiveoverseaseventquest()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	DELETE 

	FROM user_quest 

	WHERE user_quest.quest_id >= 49000 AND user_quest.quest_id <= 49999 

			AND quest_id not in (select quest_id from overseas_event_quest)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_cleaninactiveoverseaseventquest;
-- +goose StatementEnd
