-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getcharbotchannel.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharbotchannel(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin 

	select COALESCE(use_bot_channel, 0) from user_extra_info where char_id = _char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharbotchannel;
-- +goose StatementEnd
