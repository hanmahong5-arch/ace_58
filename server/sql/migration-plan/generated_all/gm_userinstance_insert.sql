-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserInstance_Insert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userinstance_insert(_char_id INTEGER, _world_id INTEGER, _instance_id INTEGER, _reentrance_time INTEGER, _server_id INTEGER, _count_variate INTEGER, _kina_increase INTEGER, _item_increase INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

		INSERT INTO user_instance (char_id, world_id, instance_id, reentrance_time, server_id, count_variate, kina_increase, item_increase)

		VALUES (_char_id, _world_id, _instance_id, _reentrance_time, _server_id, _count_variate, _kina_increase, _item_increase)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userinstance_insert;
-- +goose StatementEnd
