-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_RemovePet.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removepet(_id BIGINT, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- use char_id for double check

--	delete from user_pet where id = _id and char_id = _char_id

	delete from user_pet where name_Id = _id and char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removepet;
-- +goose StatementEnd
