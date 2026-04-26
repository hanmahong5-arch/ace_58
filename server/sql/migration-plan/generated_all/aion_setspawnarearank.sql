-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetSpawnAreaRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setspawnarearank(_world_no INTEGER, _spawn_area_name TEXT, _rank INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select world_no from spawn_area_rank(UPDLOCK) where world_no=_world_no and spawn_area_name=_spawn_area_name) 

	begin		

		update spawn_area_rank set rank=_rank where world_no=_world_no and spawn_area_name=_spawn_area_name

	end

else 

	begin		

		insert spawn_area_rank(world_no, spawn_area_name, rank) values(_world_no, _spawn_area_name, _rank)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setspawnarearank;
-- +goose StatementEnd
