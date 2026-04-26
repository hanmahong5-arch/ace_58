-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserLunaDA_DeleteUserLunaPriceForPCCopy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userlunada_deleteuserlunapriceforpccopy(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	DELETE FROM user_luna_price WHERE char_id = _char_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userlunada_deleteuserlunapriceforpccopy;
-- +goose StatementEnd
