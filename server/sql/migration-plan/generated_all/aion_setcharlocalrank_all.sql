-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharLocalRank_All.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharlocalrank_all(_rank_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	

	UPDATE user_rank SET local_old_ranking = local_ranking, local_ranking = 0 WHERE rank_id = _rank_id

	

	UPDATE user_rank SET local_ranking = num 

	from 

	(

		select RANK() over (partition by user_data.race order by point desc) as num, rank_id, user_rank.char_id

		from user_rank with(nolock)

		join user_data with(nolock) on user_rank.char_id = user_data.char_id and user_data.delete_complete_date = 0

		where rank_id = _rank_id and point > 0

	) x

	where x.num <= 1000 and user_rank.rank_id = x.rank_id and user_rank.char_id = x.char_id

	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharlocalrank_all;
-- +goose StatementEnd
