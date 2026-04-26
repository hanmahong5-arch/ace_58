-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_setitemreidentifycount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemreidentifycount(_itemid BIGINT, _count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	update user_item_option set reidentify_count = _count where id = _itemid


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemreidentifycount;
-- +goose StatementEnd
