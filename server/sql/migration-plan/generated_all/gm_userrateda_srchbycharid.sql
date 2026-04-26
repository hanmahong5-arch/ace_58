-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRateDA_SrchByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrateda_srchbycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	set transaction isolation level read uncommitted

	set ansi_warnings off



	SELECT	r.rate_rank, r.rate_id, r.mu, r.sigma, r.update_cnt,

			u.char_id, u.user_id, u.account_id, u.account_name, u.race, u.class, u.guild_id, u.gender, u.lev,

			g.name as 'guild_nm'

	FROM	

	(

		SELECT	RANK() OVER (PARTITION BY rate_id ORDER BY mu DESC, sigma) AS 'rate_rank', rate_id, mu, sigma, update_cnt, char_id

		FROM	user_rate

	) r

	JOIN	user_data u	ON u.char_id = r.char_id

	LEFT JOIN	guild g	ON g.id = u.guild_id

	WHERE	u.char_id = _char_id

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrateda_srchbycharid;
-- +goose StatementEnd
