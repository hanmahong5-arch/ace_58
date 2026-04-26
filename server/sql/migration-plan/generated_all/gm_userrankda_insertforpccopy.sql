-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRankDA_InsertForPCCopy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrankda_insertforpccopy(_char_id INTEGER, _rank_id INTEGER, _point INTEGER, _global_ranking INTEGER, _global_old_ranking INTEGER, _local_ranking INTEGER, _local_old_ranking INTEGER, _last_ranking INTEGER, _last_point INTEGER, _best_ranking INTEGER, _best_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	INSERT INTO user_rank (char_id, rank_id, point, global_ranking, global_old_ranking, local_ranking, local_old_ranking, last_ranking, last_point, best_ranking, best_point)

	VALUES (_char_id, _rank_id, _point, _global_ranking, _global_old_ranking, _local_ranking, _local_old_ranking, _last_ranking, _last_point, _best_ranking, _best_point)



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrankda_insertforpccopy;
-- +goose StatementEnd
