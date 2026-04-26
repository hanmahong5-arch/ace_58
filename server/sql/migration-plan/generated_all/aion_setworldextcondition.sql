-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetWorldExtCondition.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setworldextcondition(_world_num INTEGER, _variable TEXT, _variable_hash INTEGER, _value INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE	_id	int

	_id := 0



	SELECT id INTO _id FROM world_extcondition(updlock) WHERE world_type = 0 AND world_num = _world_num AND variable_hash = _variable_hash

	IF (@_rowcount > 1)

		SELECT _id = id FROM world_extcondition WHERE world_type = 0 AND world_num = _world_num AND variable = _variable



	IF (_id <> 0)

		UPDATE world_extcondition SET value = _value WHERE id = _id

	ELSE

		INSERT INTO world_extcondition (world_type, world_num, variable, variable_hash, value) VALUES (0, _world_num, _variable, _variable_hash, _value)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setworldextcondition;
-- +goose StatementEnd
