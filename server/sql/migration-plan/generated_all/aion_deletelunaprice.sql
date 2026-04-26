-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_deletelunaprice.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletelunaprice(_char_id INTEGER, _luna_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin	


	delete from user_luna_price where char_id = _char_id and luna_id = _luna_id	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletelunaprice;
-- +goose StatementEnd
