-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateTitle.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatetitle(_char_id INTEGER, _title_id INTEGER, _expired INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT char_id FROM user_title(updlock) WHERE char_id = _char_id and  title_id=_title_id)

begin

	UPDATE user_title SET is_have = _have, expired_time = _expired WHERE char_id = _char_id and  title_id=_title_id

end

else

begin	

	INSERT user_title (char_id, title_id, is_have, expired_time) VALUES (_char_id, _title_id, _have, _expired)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatetitle;
-- +goose StatementEnd
