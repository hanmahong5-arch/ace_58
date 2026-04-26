-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSkillList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskilllist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT skill_id, skill_data1, skill_data2

FROM user_skill

WHERE char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskilllist;
-- +goose StatementEnd
