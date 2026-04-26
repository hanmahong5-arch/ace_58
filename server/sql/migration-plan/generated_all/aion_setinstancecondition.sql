-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInstanceCondition.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstancecondition(_instance_id INTEGER, _variable TEXT, _variable_hash INTEGER, _value INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE	_id	int

	_id := 0



	SELECT id INTO _id FROM world_extcondition(updlock) WHERE world_type = 1 AND world_num = _instance_id AND variable_hash = _variable_hash

	IF (@_rowcount > 1)

		SELECT _id = id FROM world_extcondition WHERE world_type = 1 AND world_num = _instance_id AND variable = _variable



	IF (_id <> 0)

		UPDATE world_extcondition SET value = _value WHERE id = _id

	ELSE

		INSERT INTO world_extcondition (world_type, world_num, variable, variable_hash, value) VALUES (1, _instance_id, _variable, _variable_hash, _value)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstancecondition;
-- +goose StatementEnd
