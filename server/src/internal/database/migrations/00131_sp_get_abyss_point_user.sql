-- AionCore 5.8 — abyss-point fetch SP, separate from the giant GetCharInfo.
--
-- No NCSoft equivalent. The 5.8 SQL Server build returns abyss_point as one
-- of the 120 columns from aion_GetCharInfo_20160818. Some runtime paths only
-- need the AP and don't want to pay full GetCharInfo cost:
--
--   scripts/handlers/cm_enter_world.lua  -- AP hydration when GetCharInfo
--                                            row didn't carry the column
--
-- Future callers (deferred until those features land):
--   - PvP-kill AP grant flow (sanity-read the current AP before delta-write)
--   - Faction leaderboards / rank UIs that scroll many chars
--
-- Returns 0 rows for missing / soft-deleted chars; callers default to 0.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssspointuser(INTEGER);
DROP FUNCTION IF EXISTS aion_getabysspointuser(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabysspointuser(_char_id INTEGER)
RETURNS TABLE (
    abyss_point BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ud.abyss_point
          FROM user_data ud
         WHERE ud.char_id     = _char_id
           AND ud.delete_date = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabysspointuser(INTEGER);
-- +goose StatementEnd
