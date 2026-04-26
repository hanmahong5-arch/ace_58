-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutBuilderCommandLog_20110225.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putbuildercommandlog_20110225(_world_id INTEGER, _user_id TEXT, _type INTEGER, _level INTEGER, _command TEXT, _parameter TEXT, _command_from INTEGER, _result_message TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



if EXISTS (SELECT BUILDER_LOG_ID FROM builder_log(UPDLOCK) WHERE CHAR_NM = _user_id and (_command_from = 1)) 

begin

	UPDATE builder_log 

	SET world_id=_world_id, build_nm=_command, build_parameter=_parameter, builder_type=_type, builder_lv=_level, command_from=_command_from, result_message = _result_message + result_message

	where CHAR_NM = _user_id and (_command_from = 1)

end

else

begin

	INSERT builder_log ( world_id, char_nm, build_nm, build_parameter, builder_type, builder_lv, regdate, command_from, result_message )

	VALUES ( _world_id, _user_id, _command, _parameter, _type, _level, NOW(), _command_from, _result_message )

end



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbuildercommandlog_20110225;
-- +goose StatementEnd
