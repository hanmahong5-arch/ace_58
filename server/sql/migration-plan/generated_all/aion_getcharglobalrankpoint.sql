-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharGlobalRankPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharglobalrankpoint(_rank_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	SELECT a.point,

		a.global_ranking,

		a.global_old_ranking,

		a.char_id,

		b.race,

		b.class,

		b.user_id

	from user_rank as a with(nolock), user_data as b with(nolock) 

	where a.char_id = b.char_id and b.delete_complete_date = 0 and a.rank_id = _rank_id and a.point > 0

	order by a.point desc

	

	return @_rowcount

end /* LIMIT 3000 appended */ LIMIT 3000;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharglobalrankpoint;
-- +goose StatementEnd
