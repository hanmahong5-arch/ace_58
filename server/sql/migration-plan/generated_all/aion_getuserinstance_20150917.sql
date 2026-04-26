-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetUserInstance_20150917.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserinstance_20150917(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

--	SELECT world_id, instance_id, reentrance_time, validity_time FROM user_instance WHERE char_id = _char_id

  --DELETE FROM user_instance WHERE char_id = _char_id AND world_id = 302350000

	SELECT ui.server_id, ui.world_id, ui.instance_id, ui.reentrance_time, ui.count_variate, i.validity_time, ui.kina_increase, ui.item_increase FROM user_instance as ui LEFT OUTER JOIN instance as i ON ui.instance_id = i.instance_id WHERE ui.char_id = _char_id



--	DELETE FROM user_instance WHERE char_id = _char_id AND validity_time <= _curtime

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserinstance_20150917;
-- +goose StatementEnd
