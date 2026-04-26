-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRankDA_SrchUserListByRankId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrankda_srchuserlistbyrankid(_rank_id INTEGER, _cvs_race TEXT, _cvs_class TEXT, _rank_from INTEGER, _rank_to INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




		set transaction isolation level read uncommitted

		set ansi_warnings off



		DECLARE	_sql varchar(4000)

		_sql := '

			SELECT r.*, u.user_id, u.char_id, u.race, u.class, u.gender, u.lev, u.account_name, u.account_id, g.name as ''guild_nm''

			FROM user_rank r (nolock)

				JOIN user_data u (nolock) ON u.char_id = r.char_id

				LEFT JOIN guild g (nolock) ON g.id = u.guild_id

			WHERE r.rank_id = ' + convert(varchar, _rank_id)



		-- 종족조건

		IF (COALESCE(_cvs_race, 'null') <> 'null')

		BEGIN

			_sql := _sql + ' AND u.race IN (' + _cvs_race + ') '

		END



		-- 직업조건

		IF (COALESCE(_cvs_class, 'null') <> 'null')

		BEGIN

			_sql := _sql + ' AND u.class IN (' + _cvs_class + ') '

		END



		-- 랭크조건

		_sql := _sql + ' AND ' + convert(varchar, _rank_from) + '<= local_ranking AND local_ranking <=' + convert(varchar, _rank_to)

		SET _sql += ' ORDER BY r.local_ranking ASC'

		EXEC(_sql)



	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrankda_srchuserlistbyrankid;
-- +goose StatementEnd
