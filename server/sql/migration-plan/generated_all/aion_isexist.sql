-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_IsExist.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_isexist(_char_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT char_id FROM user_data WHERE user_id=_char_name and delete_complete_date = 0

if(@_r_o_w_c_o_u_n_t=0)

	return 0


return 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_isexist;
-- +goose StatementEnd
