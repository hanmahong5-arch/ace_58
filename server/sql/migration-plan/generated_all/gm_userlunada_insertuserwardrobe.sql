-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserLunaDA_InsertUserWardrobe.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userlunada_insertuserwardrobe(_char_id INTEGER, _slot_id INTEGER, _name_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT	user_wardrobe (char_id, slot_id, name_id)

	VALUES	(_char_id, _slot_id, _name_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userlunada_insertuserwardrobe;
-- +goose StatementEnd
