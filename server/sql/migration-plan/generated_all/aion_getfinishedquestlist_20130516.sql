-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetFinishedQuestList_20130516.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getfinishedquestlist_20130516(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
--update user_finished_quest with (updlock)

--set repeat_quest_count = repeat_quest_count - repeat_quest_resetnum, --repeat_quest_resetnum = 0

--WHERE char_id=_user_id



update user_finished_quest with (updlock)

set repeat_quest_count = 0

where char_id=_user_id and repeat_quest_count < 0 



SELECT quest_id, quest_count, quest_branch, COALESCE(quest_finishedtime, 0), repeat_quest_count, repeat_quest_resetnum

FROM user_finished_quest (nolock)

WHERE char_id=_user_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfinishedquestlist_20130516;
-- +goose StatementEnd
