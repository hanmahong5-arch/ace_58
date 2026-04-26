-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserQuestDAO_FinishedQuestADDandDEL.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userquestdao_finishedquestaddanddel(_char_id TEXT, _quest_id TEXT, _quest_count INTEGER, _quest_branch TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT quest_id FROM user_finished_quest (UPDLOCK) WHERE  char_id=_char_id and quest_id=_quest_id ) 

		begin

			UPDATE user_finished_quest

			SET quest_count = _quest_count , quest_branch = _quest_branch  

			WHERE char_id=_char_id and quest_id=_quest_id 

		end

		else

		begin

			INSERT into user_finished_quest(char_id, quest_id, quest_count, quest_branch) 

			VALUES (_char_id, _quest_id, _quest_count, _quest_branch)	

		end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userquestdao_finishedquestaddanddel;
-- +goose StatementEnd
