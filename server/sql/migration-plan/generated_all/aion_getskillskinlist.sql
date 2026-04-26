-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSkillSkinList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskillskinlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




SELECT  skill_skin_id, expire_time, use_skin FROM user_skill_skin WHERE (char_id = _char_id) AND (expire_time > 0)




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillskinlist;
-- +goose StatementEnd
