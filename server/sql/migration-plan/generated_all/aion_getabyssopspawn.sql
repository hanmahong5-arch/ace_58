-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAbyssOPSpawn.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssopspawn()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT npc_name_id FROM abyss_op_spawn WITH(NOLOCK) WHERE spawn != 0


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssopspawn;
-- +goose StatementEnd
