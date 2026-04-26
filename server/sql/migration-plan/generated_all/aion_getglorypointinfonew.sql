-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGloryPointInfoNew.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getglorypointinfonew(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT COALESCE(glory_point,0), COALESCE(ownership_bonus_gp,0), today_glory_point, this_week_glory_point, last_week_glory_point FROM user_data LEFT OUTER JOIN user_gp_data ON user_data.char_id=user_gp_data.char_id WHERE user_data.char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getglorypointinfonew;
-- +goose StatementEnd
