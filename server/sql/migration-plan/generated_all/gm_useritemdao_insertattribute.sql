-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertAttribute.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertattribute(_id BIGINT, _attribute1 INTEGER, _attribute1value INTEGER, _attribute2 INTEGER, _attribute2value INTEGER, _attribute3 INTEGER, _attribute3value INTEGER, _attribute4 INTEGER, _attribute4value INTEGER, _attribute5 INTEGER, _attribute5value INTEGER, _attribute6 INTEGER, _attribute6value INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

				insert into user_item_attribute (id, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute1value, attribute2value, attribute3value, attribute4value, attribute5value, attribute6value)

				values (_id, _attribute1, _attribute2, _attribute3, _attribute4, _attribute5, _attribute6, _attribute1value, _attribute2value, _attribute3value, _attribute4value, _attribute5value, _attribute6value)

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertattribute;
-- +goose StatementEnd
