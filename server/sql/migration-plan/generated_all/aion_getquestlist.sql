-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetQuestList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getquestlist(_user_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT quest_id, quest_status, quest_progress, quest_branch

FROM user_quest

WHERE char_id=_user_id

ORDER BY quest_id asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getquestlist;
-- +goose StatementEnd
