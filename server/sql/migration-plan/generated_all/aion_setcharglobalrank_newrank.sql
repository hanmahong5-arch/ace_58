-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharGlobalRank_NewRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharglobalrank_newrank(_char_id INTEGER, _rank_id INTEGER, _new_ranking INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	

	UPDATE user_rank SET global_ranking = _new_ranking WHERE char_id = _char_id AND rank_id = _rank_id

	

	if (@_r_o_w_c_o_u_n_t = 0)

	begin

		INSERT INTO user_rank (char_id, rank_id, global_ranking, point) values (_char_id, _rank_id, _new_ranking, 0)

	end

	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharglobalrank_newrank;
-- +goose StatementEnd
