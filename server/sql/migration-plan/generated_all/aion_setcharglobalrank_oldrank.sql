-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharGlobalRank_OldRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharglobalrank_oldrank(_rank_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	UPDATE user_rank SET global_old_ranking = global_ranking, global_ranking = 0 where rank_id = _rank_id


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharglobalrank_oldrank;
-- +goose StatementEnd
