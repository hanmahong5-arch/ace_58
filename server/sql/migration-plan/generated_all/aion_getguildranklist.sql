-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildRankList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildranklist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



--CNATION: 더이상사용하지 않습니다.



	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


/*

UPDATE guild SET rank=0 WHERE rank > 0



UPDATE guild set rank = RankList.rnk 

	from ( SELECT id, rnk = RANK() over (order by point desc,id desc ) from guild order by point desc,id desc) as RankList 

	where guild.id = RankList.id



SELECT top 100 id, point

FROM guild

WHERE rank <> 0

ORDER BY rank

*/


END /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildranklist;
-- +goose StatementEnd
