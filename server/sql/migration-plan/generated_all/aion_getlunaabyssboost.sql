-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetLunaAbyssBoost.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getlunaabyssboost(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT abyss_id, is_boost_on FROM user_luna_abyss_boost WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getlunaabyssboost;
-- +goose StatementEnd
