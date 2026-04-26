-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserInstance_20150311.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserinstance_20150311(_char_id INTEGER, _world_id INTEGER, _instance_id INTEGER, _reentrance_time INTEGER, _server_id INTEGER, _count_variate INTEGER, _kina_increase INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

    -- Insert statements for procedure here

	IF EXISTS (SELECT char_id FROM user_instance(updlock) WHERE char_id = _char_id AND world_id = _world_id)

		UPDATE user_instance SET instance_id = _instance_id, reentrance_time = _reentrance_time, server_id = _server_id, count_variate = _count_variate,kina_increase=_kina_increase  WHERE char_id = _char_id AND world_id = _world_id

	ELSE

		INSERT user_instance(char_id, world_id, instance_id, reentrance_time, server_id, count_variate, kina_increase) VALUES (_char_id, _world_id, _instance_id, _reentrance_time, _server_id, _count_variate, _kina_increase)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserinstance_20150311;
-- +goose StatementEnd
