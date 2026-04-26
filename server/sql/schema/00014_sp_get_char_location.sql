-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetCharLocation (PG-only).
--
-- Resolves Round 4 MISSING entry "aion_GetCharLocation" — NCSoft folds these
-- columns into aion_GetCharInfo_20160818 (which reads ~120 cols and is
-- TODO-flagged in this round). Since the runtime needs to restore coords on
-- login (cm_enter_world.lua), we expose a focused PG-only lookup.
-- (decision logged in priority-50.md)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharlocation(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharlocation(_char_id INTEGER)
RETURNS TABLE (
    cur_server INTEGER,
    world      INTEGER,
    xlocation  REAL,
    ylocation  REAL,
    zlocation  REAL,
    dir        INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT u.cur_server, u.world, u.xlocation, u.ylocation, u.zlocation, u.dir
      FROM user_data u
     WHERE u.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharlocation(INTEGER);
-- +goose StatementEnd
