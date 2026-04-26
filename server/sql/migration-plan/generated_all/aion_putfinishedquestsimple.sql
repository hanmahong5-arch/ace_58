-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_putFinishedQuestSimple.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfinishedquestsimple(_charid INTEGER, _quest_id INTEGER, _branch INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	INSERT user_finished_quest (char_id, quest_id, quest_count, quest_branch, quest_finishedtime, repeat_quest_count)

		VALUES (_charid, _quest_id, 1, _branch, 0, 1)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfinishedquestsimple;
-- +goose StatementEnd
