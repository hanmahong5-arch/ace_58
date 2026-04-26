-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_OrderingAbyssRanking_20160415.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_orderingabyssranking_20160415(_special_svr INTEGER, _server_id INTEGER, _race INTEGER, _time BIGINT, _num INTEGER, _this_week_update_time INTEGER, _recent_g_p_min INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _update_time bigint

_update_time := COALESCE((select max(update_time) from abyss_ranking where race = _race and server_id = _server_id), 0)



IF (0 = _special_svr)

	BEGIN

		/* gp 없는 애들 테이블에서 제거 */

		delete from user_gp_data where glory_point<=0 and ownership_bonus_gp<=0



		insert into abyss_ranking (abyss_ranking, server_id, update_time, char_id, abyss_point, race, class, lev, guild_id, rank, old_Ranking, gp, rank_updatedate)

		select top (_num) RANK() over (order by (COALESCE(glory_point, 0) + COALESCE(ownership_bonus_gp, 0)) desc, abyss_point desc, lev desc, user_data.char_id asc) as rank, _server_id, _time, user_data.char_id, abyss_point, race, class, lev, guild_id, 0, 0, (COALESCE(glory_point, 0) + COALESCE(ownership_bonus_gp, 0)) AS gp_sum, NULL

		from user_data LEFT OUTER JOIN user_gp_data ON user_data.char_id=user_gp_data.char_id

		where race = _race

		and org_server = _server_id

		and (delete_date = 0 or delete_date > _time)

		and (DateDiff(day, last_logout_time, NOW()) < 30)	-- 한달 이내

		and (case when (this_week_compare_time = _this_week_update_time or (_this_week_update_time / 86400) = (this_week_compare_time / 86400)) then (CONVERT(bigint, this_week_glory_point) + last_week_glory_point + two_weeks_ago_glory_point + three_weeks_ago_glory_point)

					when (this_week_compare_time >= (_this_week_update_time - 604800)  or ((_this_week_update_time / 86400)-7) = (this_week_compare_time / 86400)) then (CONVERT(bigint,this_week_glory_point) + last_week_glory_point + two_weeks_ago_glory_point)

					when (this_week_compare_time >= (_this_week_update_time - 1209600) or ((_this_week_update_time / 86400)-14) = (this_week_compare_time / 86400)) then (CONVERT(bigint,this_week_glory_point) + last_week_glory_point)

					when (this_week_compare_time >= (_this_week_update_time - 1814400) or ((_this_week_update_time / 86400)-21) = (this_week_compare_time / 86400)) then this_week_glory_point

					end) >= _recent_g_p_min

		order by rank

	END

ELSE

	/* 특화서버 */

	BEGIN

		insert into abyss_ranking (abyss_ranking, server_id, update_time, char_id, abyss_point, race, class, lev, guild_id, rank, old_Ranking, gp, rank_updatedate)

		select top (_num) RANK() over (order by abyss_point desc, lev desc, user_data.char_id asc) as rank, _server_id, _time, user_data.char_id, abyss_point, race, class, lev, guild_id, 0, 0, (COALESCE(glory_point, 0) + COALESCE(ownership_bonus_gp, 0)) AS gp_sum, NULL

		from user_data LEFT OUTER JOIN user_gp_data ON user_data.char_id=user_gp_data.char_id

		where race = _race

		and org_server = _server_id

		and (delete_date = 0 or delete_date > _time)

		and (DateDiff(day, last_logout_time, NOW()) < 30)	-- 한달 이내

		order by rank

	END



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
DROP FUNCTION IF EXISTS aion_orderingabyssranking_20160415;
-- +goose StatementEnd
