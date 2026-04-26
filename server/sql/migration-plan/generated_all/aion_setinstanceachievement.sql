-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInstanceAchievement.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstanceachievement(_char_id INTEGER, _world_id INTEGER, _spawn_page INTEGER, _version INTEGER, _data BYTEA)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	IF EXISTS (SELECT id FROM user_instance_achievement(updlock) WHERE char_id = _char_id AND world_id = _world_id AND spawn_page = _spawn_page AND version = _version)

	BEGIN

		UPDATE user_instance_achievement SET data = _data WHERE char_id = _char_id AND world_id = _world_id AND spawn_page = _spawn_page AND version = _version

	END

	ELSE

	BEGIN

		INSERT INTO user_instance_achievement(char_id, world_id, spawn_page, version, data) VALUES (_char_id, _world_id, _spawn_page, _version, _data)

	END    

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceachievement;
-- +goose StatementEnd
