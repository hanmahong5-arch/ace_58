-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchAbyssInfoByID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssinfobyid(_abyss_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT	a.abyss_id, a.owner_guild, a.owner_race, a.defense_count, a.reward, a.cur_pvp_status, a.next_pvp_status, a.door_upgrade_point, a.shield_upgrade_point, a.peace_count

					, COALESCE(g.name, '') as name, COALESCE(g.point, 0) as point, COALESCE(g.fund, 0) as fund, COALESCE(g.master_id, '') as master_id

					, COALESCE(u.user_id, '') as user_id

					, a.owner_char_id, a.last_ownership_bonus_gp

					-- [4.71] 그랜드어비스, 연속점령제한

					, a.owner_server , a.occupy_count, a.occupy_point, a.occupy_bonus

					-- [5.3] 어비스 수호령 관련 각 종족 연속 점령 횟수

					, a.occupy_reward_count_l, a.occupy_reward_count_d

			FROM	abyss a(nolock)

			LEFT JOIN guild g(nolock) on a.owner_guild = g.id

			LEFT JOIN user_data u(nolock) on g.master_id = u.char_id

			WHERE	a.abyss_id = _abyss_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchabyssinfobyid;
-- +goose StatementEnd
