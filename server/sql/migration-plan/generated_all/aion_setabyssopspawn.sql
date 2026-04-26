-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAbyssOPSpawn.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssopspawn(_npc_name_id INTEGER, _spawn INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




IF EXISTS (SELECT npc_name_id FROM abyss_op_spawn (UPDLOCK) WHERE npc_name_id = _npc_name_id) 

begin

	UPDATE abyss_op_spawn

	SET spawn = _spawn,

		last_update_time = NOW()

	WHERE npc_name_id = _npc_name_id

end

else

	BEGIN

		INSERT abyss_op_spawn

		VALUES (_npc_name_id, _spawn, NOW())

	END

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssopspawn;
-- +goose StatementEnd
