-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharInfoBasic.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharinfobasic(_char_i_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT account_id,class,guild_id, user_id, guild_rank FROM user_data WHERE char_id = _char_i_d;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharinfobasic;
-- +goose StatementEnd
