-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemExtendInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemextendinfo(_id BIGINT, _owner_id INTEGER, _customvalue INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select id from user_item_ext(UPDLOCK) where id = _id) 

	begin

		update user_item_ext set sa_custom1 = _customvalue, char_id = _owner_id where id = _id

	end

else 

	begin

		insert user_item_ext(id, char_id, sa_custom1) values (_id, _owner_id, _customvalue)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemextendinfo;
-- +goose StatementEnd
