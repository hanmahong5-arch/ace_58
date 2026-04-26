-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemOwnerId_GM_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemownerid_gm_20111227(_item_id BIGINT, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET char_id = _char_id,  update_date = NOW()  WHERE id = _item_id

UPDATE user_item_option SET char_id = _char_id WHERE id = _item_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemownerid_gm_20111227;
-- +goose StatementEnd
