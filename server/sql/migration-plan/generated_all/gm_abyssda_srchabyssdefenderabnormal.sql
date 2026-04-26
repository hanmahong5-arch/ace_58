-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchAbyssDefenderAbnormal.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssdefenderabnormal(_abyss_id INTEGER, _tick_from INTEGER, _tick_to INTEGER, _valid_siege_point INTEGER, _invalid_char_count INTEGER, _normal_rank_to INTEGER, _normal_count_to INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SET	TRANSACTION ISOLATION LEVEL READ UNCOMMITTED



	SELECT r.update_time, r.abyss_id, 

			--dateadd(second, r.update_time, '1970-01-01') as 'update_time2', -- test

			c.contributer_total, 

			r.defender_share_amount, r.defender_rank, r.defender_siegepoint, r.group_id,

			u.char_id, u.user_id, u.account_id, u.account_name,

			u.race, u.class, convert(char,u.gender) as gender,

			COALESCE(u.login_server, u.org_server) login_server, u.org_server, u.cur_server, u.world, u.lev, u.builder, convert(varchar(20),u.create_date, 120) as 'create_date', 

			u.delete_type, u.delete_complete_date, u.delete_date,

			CASE WHEN u.last_login_time = u.last_logout_time THEN 'on'

				WHEN u.last_login_time != u.last_logout_time THEN 'off' END as 'logonoff'

	FROM	abyss_user_defender r	-- [1]reward

	JOIN	user_data u				-- [2]user info

			ON	r.defender_char_id = u.char_id

	JOIN(

			SELECT	abyss_id ,update_time

			FROM	abyss_user_defender

			WHERE	abyss_id = _abyss_id AND _tick_from <= update_time AND update_time <= _tick_to

			AND		defender_rank = 1 AND defender_share_amount <= _valid_siege_point

			GROUP BY abyss_id, update_time

			HAVING	_invalid_char_count <= count(defender_char_id)	-- 랭크 1인데 공훈도가 _valid_siege_point 이하인 캐릭터수가 _invalid_char_count 이상

			UNION

			SELECT	abyss_id ,update_time

			FROM	abyss_user_defender

			WHERE	abyss_id = _abyss_id AND _tick_from <= update_time AND update_time <= _tick_to

			AND		defender_rank <= _normal_rank_to

			GROUP BY abyss_id, update_time

			HAVING	count(defender_char_id) < _normal_count_to		-- 랭크 1 ~ _normal_rank_to의  포상자수가 _normal_count_to에 미달

			) s		-- [3]abnormal siege

			ON	s.abyss_id = r.abyss_id AND s.update_time = r.update_time

	JOIN(

			SELECT	abyss_id, update_time, count(abyss_id) as 'contributer_total'

			FROM	abyss_user_defender

			GROUP BY abyss_id, update_time

			) c		-- [4]contributer total count

			ON	c.abyss_id = s.abyss_id AND c.update_time = s.update_time

	ORDER BY u.char_id, r.abyss_id, r.update_time desc

	

END /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchabyssdefenderabnormal;
-- +goose StatementEnd
