-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: rename_constraint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION rename_constraint(_table TEXT, _column TEXT, _name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	declare _name varchar(250)

	exec get_constraint_name _table, _column, _name output
RAISE NOTICE '%', _name;

	

	exec sp_rename _name, _name, N'object'

	

	exec get_constraint_name _table, _column, _name output
RAISE NOTICE '%', _name;

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS rename_constraint;
-- +goose StatementEnd
