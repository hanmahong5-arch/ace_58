-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharLocalRankPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharlocalrankpoint(_rank_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	

	select 

		a.point,

		a.local_ranking,

		a.local_old_ranking,

		a.char_id,

		b.race,

		b.class,

		b.user_id

	from user_rank as a with(nolock), user_data as b with(nolock) 

	where a.char_id = b.char_id and a.rank_id = _rank_id and a.local_ranking <= 1000 and a.local_ranking != 0

	order by point desc

			

	return @_rowcount

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharlocalrankpoint;
-- +goose StatementEnd
