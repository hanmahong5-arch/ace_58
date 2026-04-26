-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutOverseasEventQuest.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putoverseaseventquest(_quest_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	INSERT overseas_event_quest(quest_id)

	VALUES (_quest_id)

	


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putoverseaseventquest;
-- +goose StatementEnd
