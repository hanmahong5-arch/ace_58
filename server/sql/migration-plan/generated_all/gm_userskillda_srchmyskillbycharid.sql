-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserSkillDA_SrchMySkillByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userskillda_srchmyskillbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	char_id, skill_id, skill_data1, skill_data2

			from	user_skill(nolock)

			where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userskillda_srchmyskillbycharid;
-- +goose StatementEnd
