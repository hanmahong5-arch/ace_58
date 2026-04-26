-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetUserWeeklyRewardTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserweeklyrewardtime()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	SELECT user_week_reward_time from abyss_reward_update_time

end /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserweeklyrewardtime;
-- +goose StatementEnd
