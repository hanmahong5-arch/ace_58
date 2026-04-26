-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharGlobalRank_SeasonRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharglobalrank_seasonrank(_rank_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	

	UPDATE user_rank 

	SET last_ranking = global_ranking, last_point = point

	WHERE rank_id = _rank_id

		

	UPDATE user_rank

	SET best_ranking = last_ranking

	WHERE rank_id = _rank_id and last_ranking > 0  and (best_ranking > last_ranking or best_ranking = 0)

	

	UPDATE user_rank 

	SET best_point = last_point

	WHERE rank_id = _rank_id and best_point < last_point

	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharglobalrank_seasonrank;
-- +goose StatementEnd
