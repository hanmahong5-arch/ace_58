-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSpawnAreaRankList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getspawnarearanklist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select world_no, spawn_area_name, rank from spawn_area_rank;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getspawnarearanklist;
-- +goose StatementEnd
