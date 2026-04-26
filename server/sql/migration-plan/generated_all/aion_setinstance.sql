-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInstance.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstance(_instance_id INTEGER, _validity_time INTEGER, _spawn_page INTEGER, _phase TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	IF EXISTS (SELECT instance_id FROM instance(updlock) WHERE instance_id = _instance_id)

		UPDATE instance SET validity_time = _validity_time, spawn_page = _spawn_page, phase_data = _phase WHERE instance_id = _instance_id

	ELSE

		INSERT INTO instance (instance_id, validity_time, spawn_page, phase_data) VALUES (_instance_id, _validity_time, _spawn_page, _phase) 

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstance;
-- +goose StatementEnd
