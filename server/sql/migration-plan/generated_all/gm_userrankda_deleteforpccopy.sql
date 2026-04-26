-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRankDA_DeleteForPCCopy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrankda_deleteforpccopy(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	DELETE FROM user_rank WHERE char_id = _char_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrankda_deleteforpccopy;
-- +goose StatementEnd
