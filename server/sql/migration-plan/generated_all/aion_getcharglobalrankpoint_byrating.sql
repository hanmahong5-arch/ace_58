-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharGlobalRankPoint_byRating.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharglobalrankpoint_byrating(_rate_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin	

	SELECT CONVERT(int, c.mu),

		COALESCE(a.global_ranking, 0),

		COALESCE(a.global_old_ranking, 0),

		c.char_id,

		b.race,

		b.class,

		b.user_id

	from user_rate as c with(nolock) 

		left join user_rank as a with(nolock) on c.char_id = a.char_id and a.rank_id = _rate_id

		join user_data as b with(nolock) on c.char_id = b.char_id

	where c.rate_id = _rate_id and b.delete_complete_date = 0 and c.update_cnt >= 5

	order by c.mu desc

	

	return @_rowcount

end /* LIMIT 3000 appended */ LIMIT 3000;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharglobalrankpoint_byrating;
-- +goose StatementEnd
