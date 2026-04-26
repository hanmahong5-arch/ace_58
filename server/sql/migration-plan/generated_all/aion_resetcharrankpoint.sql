-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ResetCharRankPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetcharrankpoint(_rank_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	update user_rank 

	set point = 0, global_ranking = 0, global_old_ranking = 0, local_ranking = 0, local_old_ranking = 0

	where rank_id = _rank_id


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetcharrankpoint;
-- +goose StatementEnd
