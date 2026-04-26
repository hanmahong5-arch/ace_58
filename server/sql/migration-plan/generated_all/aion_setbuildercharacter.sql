-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetBuilderCharacter.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setbuildercharacter(_char_id INTEGER, _builder_lev INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _return_id INT

_return_id := 0



UPDATE user_data SET builder =  _builder_lev WHERE char_id = _char_id

IF @_r_o_w_c_o_u_n_t > 0

BEGIN

	_return_id := _char_id

END

RETURN _return_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setbuildercharacter;
-- +goose StatementEnd
