-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_addErrorIgnore.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_adderrorignore(_ignore TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
begin

	declare _count int

	SELECT COUNT(*) INTO _count from error_ignore where ignore = _ignore

	

	if _count > 0

		return

	

	insert into error_ignore values(_ignore)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_adderrorignore;
-- +goose StatementEnd
