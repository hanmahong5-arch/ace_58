-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharSeasonRankerId_byRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharseasonrankerid_byrank(_rank_id INTEGER, _score INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	select char_id, global_ranking

	from user_rank (nolock) 

	where rank_id = _rank_id and global_ranking <= _score and global_ranking != 0

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharseasonrankerid_byrank;
-- +goose StatementEnd
