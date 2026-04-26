-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetLunaAbyssBoost.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setlunaabyssboost(_char_id INTEGER, _abyss_id INTEGER, _is_boost_on INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	UPDATE user_luna_abyss_boost SET is_boost_on = _is_boost_on  

	WHERE char_id = _char_id AND abyss_id = _abyss_id

	

	IF @_r_o_w_c_o_u_n_t = 0

	BEGIN

		INSERT INTO user_luna_abyss_boost(char_id, abyss_id, is_boost_on)

		VALUES (_char_id, _abyss_id, _is_boost_on)

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setlunaabyssboost;
-- +goose StatementEnd
