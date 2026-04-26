-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharRankPoint_byRating_EndSeason.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharrankpoint_byrating_endseason(_rank_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin


	

	INSERT INTO user_rank(char_id, rank_id, point)

		select char_id, _rank_id, CONVERT(int, mu) 

		from user_rate 

		where rate_id = _rank_id and update_cnt >=5 and char_id not in (select char_id from user_rank where rank_id = _rank_id)

		

		

	UPDATE user_rank 

	SET point = -2147483648 

	WHERE rank_id = _rank_id and char_id not in (select char_id from user_rate where rate_id = _rank_id)

	


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharrankpoint_byrating_endseason;
-- +goose StatementEnd
