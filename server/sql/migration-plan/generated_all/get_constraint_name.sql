-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: get_constraint_name.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION get_constraint_name(_table TEXT, _column TEXT, _name TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 	

	

	SELECT default_constraints.name INTO _name

	from sys.all_columns

		inner join

		sys.tables on all_columns.object_id = tables.object_id

		inner join 

		sys.schemas on tables.schema_id = schemas.schema_id

		inner join 

		sys.default_constraints on all_columns.default_object_id = default_constraints.object_id

	where schemas.name = 'dbo' and tables.name = _table and all_columns.name = _column			

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS get_constraint_name;
-- +goose StatementEnd
