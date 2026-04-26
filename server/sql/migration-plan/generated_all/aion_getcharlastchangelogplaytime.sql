-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharLastChangeLogPlayTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharlastchangelogplaytime(_char_id INTEGER, _type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _playtime int

_playtime := (SELECT playtime from user_change_log where char_id = _char_id and change_type = _type order by change_time desc)

if (_playtime is null)

begin

	_playtime := 0

end

return _playtime
 /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharlastchangelogplaytime;
-- +goose StatementEnd
