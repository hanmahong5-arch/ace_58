-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_DeleteItemForRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_deleteitemforrecovery(_char_id INTEGER, _warehouse INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
delete from user_item 

where char_id=_char_id 

and warehouse=_warehouse

and amount <= 0 

and name_id != 182400001;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_deleteitemforrecovery;
-- +goose StatementEnd
