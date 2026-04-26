-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateBuilderCommandLog.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatebuildercommandlog(_user_id TEXT, _result_message TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



if EXISTS (SELECT BUILDER_LOG_ID FROM builder_log(UPDLOCK) WHERE CHAR_NM = _user_id) 

begin

	UPDATE builder_log 

	SET result_message = result_message + _result_message

	where CHAR_NM = _user_id

end

else

begin

	INSERT builder_log ( world_id, char_nm, build_nm, build_parameter, builder_type, builder_lv, regdate)

	VALUES ( 0, _user_id, '', '', 0, 0, NOW())

end



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatebuildercommandlog;
-- +goose StatementEnd
