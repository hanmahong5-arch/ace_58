-- AionCore 5.8 — bind-point lookup SP for revive / instance-leave / crash-recovery.
--
-- No NCSoft equivalent. The 5.8 SQL Server build folds the bind-point columns
-- into the giant `aion_GetCharInfo_20160818` SELECT and never exposes them as
-- a standalone SP. Three Lua callers have grown that need just the bind row
-- without paying the 120-column GetCharInfo cost:
--
--   scripts/lib/instance.lua          -- instance.leave teleport-to-bind
--   scripts/handlers/cm_enter_world.lua -- S-19 phantom-instance crash-recovery guard
--   scripts/handlers/cm_revive.lua    -- death revive at bind-point
--
-- Semantics: bind-point == "last position in a non-instance world". NCSoft's
-- engine writes user_data.last_normal_* whenever the player crosses out of an
-- instance world, so reading those columns gives a safe rebirth coordinate
-- that will never resurrect the player inside a phantom dungeon (>= 300000000
-- world_id range).
--
-- Returns 0 rows for missing / soft-deleted chars; callers must treat empty
-- as "leave them where they are" rather than teleporting to (0,0,0).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbindpoint(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbindpoint(_char_id INTEGER)
RETURNS TABLE (
    world      INTEGER,
    xlocation  REAL,
    ylocation  REAL,
    zlocation  REAL,
    dir        SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ud.last_normal_world,
               ud.last_normal_xlocation,
               ud.last_normal_ylocation,
               ud.last_normal_zlocation,
               ud.last_normal_dir
          FROM user_data ud
         WHERE ud.char_id = _char_id
           AND ud.delete_date = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbindpoint(INTEGER);
-- +goose StatementEnd
