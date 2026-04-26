-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAbyssOPPointAndResetTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssoppointandresettime(_race INTEGER, _quest INTEGER, _fortress INTEGER, _artifact INTEGER, _basecamp INTEGER, _op_object INTEGER, _raid_object INTEGER, _ownership_object INTEGER, _next_reset_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




IF EXISTS (SELECT race FROM abyss_op_point (UPDLOCK) WHERE race = _race) 

begin

	UPDATE abyss_op_point

	SET quest = _quest,

		fortress = _fortress,

		artifact = _artifact,

		basecamp = _basecamp,

		op_object = _op_object,

		raid_object = _raid_object,

		ownership_object = _ownership_object,

		next_reset_time = _next_reset_time

	WHERE race = _race

end

else

	BEGIN

		INSERT abyss_op_point

		VALUES (_race, _quest, _fortress, _artifact, _basecamp, _op_object, _raid_object, _ownership_object, _next_reset_time)

	END

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssoppointandresettime;
-- +goose StatementEnd
