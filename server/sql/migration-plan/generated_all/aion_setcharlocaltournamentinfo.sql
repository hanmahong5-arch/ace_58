-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLocalTournamentInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocaltournamentinfo(_char_id INTEGER, _seq INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 


	

	UPDATE user_data_ext SET local_tnmt_apply_seq = _seq WHERE char_id = _char_id

	IF @_r_o_w_c_o_u_n_t = 0

		INSERT INTO user_data_ext (char_id, local_tnmt_apply_seq) VALUES (_char_id, _seq)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocaltournamentinfo;
-- +goose StatementEnd
