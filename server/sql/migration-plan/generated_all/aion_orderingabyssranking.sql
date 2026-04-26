-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_OrderingAbyssRanking.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_orderingabyssranking(_server_id INTEGER, _race INTEGER, _time BIGINT, _num INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
int,

	_deduction_for_rank11 as int,

	_deduction_for_rank12 as int,

	_deduction_for_rank13 as int,

	_deduction_for_rank14 as int,

	_deduction_for_rank15 as int,

	_deduction_for_rank16 as int,

	_deduction_for_rank17 as int,

	_deduction_for_rank18 as int

as




DECLARE _update_time bigint

_update_time := COALESCE((select max(update_time) from abyss_ranking where race = _race and server_id = _server_id), 0)



/* GP 차감 */

UPDATE user_gp_data SET glory_point = GetGloryPointAfterDeductionByRank(abyss_ranking.rank, glory_point, _deduction_for_rank10, _deduction_for_rank11, _deduction_for_rank12, _deduction_for_rank13, _deduction_for_rank14, _deduction_for_rank15, _deduction_for_rank16, _deduction_for_rank17, _deduction_for_rank18)

	FROM user_gp_data INNER JOIN abyss_ranking ON user_gp_data.char_id=abyss_ranking.char_id WHERE user_gp_data.glory_point > 0 AND abyss_ranking.update_time=_update_time AND abyss_ranking.server_id=_server_id AND abyss_ranking.race=_race AND abyss_ranking.rank>0

/* 차감후 gp 없는 애들 테이블에서 제거 */

delete from user_gp_data where glory_point<=0 and ownership_bonus_gp<=0



insert into abyss_ranking (abyss_ranking, server_id, update_time, char_id, abyss_point, race, class, lev, guild_id, rank, old_Ranking, gp, rank_updatedate)

select top (_num) RANK() over (order by (COALESCE(glory_point, 0) + COALESCE(ownership_bonus_gp, 0)) desc, abyss_point desc, lev desc, user_data.char_id asc) as rank, _server_id, _time, user_data.char_id, abyss_point, race, class, lev, guild_id, 0, 0, (COALESCE(glory_point, 0) + COALESCE(ownership_bonus_gp, 0)) AS gp_sum, NULL

from user_data LEFT OUTER JOIN user_gp_data ON user_data.char_id=user_gp_data.char_id

where race = _race

and org_server = _server_id

and (delete_date = 0 or delete_date > _time)

and (DateDiff(day, last_logout_time, NOW()) < 30)	-- 한달 이내

order by rank



update abyss_ranking

set old_ranking = COALESCE((select b.abyss_ranking from abyss_ranking as b where b.race = _race and b.server_id = _server_id and b.update_time = _update_time and b.char_id = abyss_ranking.char_id and b.rank != 0), 0)

where update_time = _time

and race = _race

and server_id = _server_id



delete from abyss_ranking

where update_time < (GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0) - 2419200)	-- 4주 지난 것은 삭제



exec aion_SetAbyssGuildRank _race;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_orderingabyssranking;
-- +goose StatementEnd
