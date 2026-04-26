-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchAbyssOPSpawn.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssopspawn()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



			SELECT	npc_name_id, spawn, last_update_time

			FROM	abyss_op_spawn (nolock);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchabyssopspawn;
-- +goose StatementEnd
