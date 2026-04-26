-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteSpawnAreaRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletespawnarearank(_world_no INTEGER, _spawn_area_name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM spawn_area_rank where world_no=_world_no and spawn_area_name=_spawn_area_name;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletespawnarearank;
-- +goose StatementEnd
