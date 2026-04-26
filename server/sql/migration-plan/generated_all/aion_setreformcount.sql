-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetReformCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setreformcount(_char_id INTEGER, _next_reset_time INTEGER, _reform_count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	UPDATE 

		user_reform 

	SET 

		next_reset_time = _next_reset_time, reform_count = _reform_count

	WHERE 

		char_id = _char_id

	

	IF @_r_o_w_c_o_u_n_t = 0

	BEGIN

		INSERT INTO user_reform(char_id, next_reset_time, reform_count)

		VALUES (_char_id, _next_reset_time, _reform_count)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setreformcount;
-- +goose StatementEnd
