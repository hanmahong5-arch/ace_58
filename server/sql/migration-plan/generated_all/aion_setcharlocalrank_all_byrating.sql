-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLocalRank_All_byRating.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocalrank_all_byrating(_rate_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	

	UPDATE user_rank SET local_old_ranking = local_ranking, local_ranking = 0 WHERE rank_id = _rate_id

	

	UPDATE user_rank SET local_ranking = num, point = CONVERT(int, x.mu)

	from 

	(

		select RANK() over (partition by user_data.race order by CONVERT(int, mu) desc) as num, rate_id, user_rate.char_id, user_rate.mu

		from user_rate with(nolock)

		join user_data with(nolock) on user_rate.char_id = user_data.char_id and user_data.delete_complete_date = 0

		where rate_id = _rate_id and update_cnt >= 5

	) x

	where x.num <= 1000 and user_rank.rank_id = x.rate_id and user_rank.char_id = x.char_id

	

	

	INSERT INTO user_rank (char_id, rank_id, local_ranking, point)

	SELECT x.char_id, x.rate_id, x.num, CONVERT(int, x.mu)

	from 

	(

		select RANK() over (partition by user_data.race order by CONVERT(int, mu) desc) as num, rate_id, user_rate.char_id, user_rate.mu

		from user_rate with(nolock)

		join user_data with(nolock) on user_rate.char_id = user_data.char_id and user_data.delete_complete_date = 0

		where rate_id = _rate_id and update_cnt >= 5

	) x

	where x.num <= 1000 and x.char_id not in (select char_id from user_rank where rank_id = _rate_id)

		

	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocalrank_all_byrating;
-- +goose StatementEnd
