-- AionCore 5.8 — bind-point setter SP, companion to aion_GetBindPoint.
--
-- No NCSoft equivalent. NCSoft mutates user_data.last_normal_* implicitly
-- inside the engine whenever the player's session crosses out of an instance
-- world. We don't have that engine; the world process needs an explicit hook
-- so Lua can stamp the bind row at well-defined moments:
--
--   * On enter-world for normal (non-instance) maps  → snapshot current pos
--   * On enter-instance                              → snapshot pre-warp pos
--   * On /setbind NPC interaction (priest binding)   → user-initiated rebind
--
-- Returns 1 if a row was updated, 0 if no live char_id matched. Lua callers
-- inspect this to surface "bind succeeded" feedback to the player.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbindpoint(INTEGER, INTEGER, REAL, REAL, REAL, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setbindpoint(
    _char_id   INTEGER,
    _world     INTEGER,
    _xlocation REAL,
    _ylocation REAL,
    _zlocation REAL,
    _dir       SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    UPDATE user_data
       SET last_normal_world     = _world,
           last_normal_xlocation = _xlocation,
           last_normal_ylocation = _ylocation,
           last_normal_zlocation = _zlocation,
           last_normal_dir       = _dir
     WHERE char_id    = _char_id
       AND delete_date = 0;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbindpoint(INTEGER, INTEGER, REAL, REAL, REAL, SMALLINT);
-- +goose StatementEnd
