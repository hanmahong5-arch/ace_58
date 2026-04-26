-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMaximumInstanceId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmaximuminstanceid(_current_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	-- Insert statements for procedure here

	/*

	IF EXISTS (SELECT id FROM user_instance)

	BEGIN

		SELECT max(instance_id) FROM user_instance

	END

	ELSE

	BEGIN

		SELECT 0 FROM user_instance

	END

	*/

	

	SELECT COALESCE(max(instance_id), 0) FROM user_instance WHERE instance_id < 0x90000000



--	DELETE FROM user_instance WHERE reentrance_time < _current_time 

	DELETE FROM world_extcondition WHERE world_type = 1 and world_num IN (SELECT instance_id FROM instance WHERE validity_time < _current_time)

	DELETE FROM instance WHERE validity_time < _current_time

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmaximuminstanceid;
-- +goose StatementEnd
