-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserQuestDA_SrchMyQuestByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userquestda_srchmyquestbycharid(_char_id TEXT, _quest_type TEXT, _view_count INTEGER, _top_count INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

	

	IF _quest_type = 'ing'

	BEGIN

		SELECT	quest_branch, char_id, quest_id, quest_status, quest_progress, '0' quest_count

				, 0 as repeat_quest_count, 0 as repeat_quest_resetnum

		FROM	user_quest(nolock) WHERE (char_id = _char_id) order by quest_id asc

	END 

	ELSE IF _quest_type = 'end'

	BEGIN

		SELECT	top(_view_count) 

				quest_branch, char_id, quest_id, '9999' quest_status, '0' quest_progress, quest_count

				, repeat_quest_count, repeat_quest_resetnum

		FROM	user_finished_quest(nolock)

		WHERE	(char_id =_char_id) and quest_id not in (select top(_top_count) quest_id from user_finished_quest(nolock) where char_id = _char_id order by quest_id asc)

		ORDER BY quest_id asc

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userquestda_srchmyquestbycharid;
-- +goose StatementEnd
