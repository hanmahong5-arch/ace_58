-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMonsterAchievementList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmonsterachievementlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select	char_id, achieve_id, achieved_count, achieved_grade, reward_received

	from	user_monster_achievement (nolock)

	where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmonsterachievementlist;
-- +goose StatementEnd
