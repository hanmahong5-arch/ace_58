-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRateDA_SrchUserListByRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrateda_srchuserlistbyrank(_rate_id INTEGER, _cvs_class TEXT, _rank_from INTEGER, _rank_to INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




			set transaction isolation level read uncommitted

			set ansi_warnings off



			DECLARE	_sql varchar(4000)

			_sql := '

			SELECT	x.*, g.name as ''guild_nm''

			FROM	(

				SELECT	RANK() OVER (ORDER BY r.mu DESC, r.sigma) AS rate_rank, r.rate_id, r.mu, r.sigma, r.update_cnt,

						u.char_id, u.user_id, u.account_id, u.account_name, u.race, u.class, u.guild_id, u.gender, u.lev

				FROM	user_rate r (nolock)

				JOIN	user_data u (nolock)	ON u.char_id = r.char_id and u.delete_complete_date = 0

				WHERE	r.rate_id = ' + convert(varchar, _rate_id)



			-- 직업조건

			IF (COALESCE(_cvs_class, 'null') <> 'null')

			BEGIN

				_sql := _sql + '

				AND		u.class IN (' + _cvs_class + ') '

			END



			_sql := _sql + '

			) x

			LEFT JOIN	guild g (nolock)	ON g.id = x.guild_id

			WHERE ' + convert(varchar, _rank_from) + '<= rate_rank AND rate_rank <=' + convert(varchar, _rank_to) + '

			ORDER BY rate_rank'



			EXEC (_sql)

			

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrateda_srchuserlistbyrank;
-- +goose StatementEnd
