-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAbyssGuildRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssguildrank(_race INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	-----------------------------------------------------------------------

	-- GUILD RANK도 묻어갑시당.~!!~ cnation 2008.08.18

	-- GUILD RANK 업데이트 타이밍도 유저와 똑같이 같다고 함

	-- GUILD는 ServerId처리가 없으니 무시.~! (개발망에서 길드 랭크 같이 나와서 문제 될것은 없으니.)

	UPDATE guild set old_rank = rank where race = _race

	UPDATE guild SET rank=0 WHERE race = _race

	UPDATE guild set rank = RankList.rnk 

		from ( SELECT id, rnk = RANK() over (order by point desc, point_max_time,id desc) from guild where race=_race order by point desc,point_max_time, id desc) as RankList 

		where guild.id = RankList.id



	delete from abyss_region_ranking

	insert into abyss_region_ranking select rank,old_rank,id,race,level,cnt,point,name, GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0) from guild inner join 

	(select guild_id,cnt = count(*) from user_data where guild_id !=0 group by guild_id) AS UserCount

	on guild.id = UserCount.guild_id

	where rank <= 50 and rank>0 order by race,rank 

END /* LIMIT 50 appended */ LIMIT 50;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssguildrank;
-- +goose StatementEnd
