-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAbyssUserOwnerInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssuserownerinfo(_abyss_id INTEGER, _update_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
Select owner_char_id, owner_server_id, owner_share_amount, owner_rank from abyss_user_owner

where abyss_id = _abyss_id and update_time = _update_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssuserownerinfo;
-- +goose StatementEnd
