-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRateDA_SrchUserList_del.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrateda_srchuserlist_del(_rate_id INTEGER, _cvs_class TEXT, _rank_from INTEGER, _rank_to INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
/*

	EXEC GM_UserRateDA_SrchUserList _rate_id=111, _cvs_class='0,1,2,3,4,5', _rank_from=1, _rank_to=100

	EXEC GM_UserRateDA_SrchUserList _rate_id=111, _cvs_class='0,1,2,3,4,5', _rank_from=3, _rank_to=10

*/

BEGIN




	set transaction isolation level read uncommitted

	--set ansi_warnings off	-- 사용하면 안됨(xml)



	DECLARE	_xml XML

	_xml := CONVERT(xml, '<c>'+REPLACE(_cvs_class, ',', '</c><c>')+'</c>')



	SELECT	top (_rank_to - _rank_from + 1) r.id, r.mu, r.sigma,

			u.char_id, u.user_id, u.account_id, u.account_name, u.race, u.class, u.guild_id,

			g.id as 'guild_id', g.name as 'guild_name'

	FROM	user_rate r

	JOIN	user_data u	ON u.char_id = r.char_id

	LEFT JOIN	guild g	ON g.id = u.guild_id

	WHERE	r.rate_id = _rate_id

	AND		u.class IN (SELECT n.value('.', 'tinyint') as class from _xml.nodes('c') as c(n))

	AND		r.id NOT IN (

			SELECT	top (_rank_from - 1) r2.id 

			FROM	user_rate r2

			JOIN	user_data u2 ON u2.char_id = r2.char_id

			WHERE	r2.rate_id = _rate_id

			AND		u2.class IN (SELECT n.value('.', 'tinyint') as class from _xml.nodes('c') as c(n))

			ORDER BY mu DESC, sigma

	)

	ORDER BY mu DESC, sigma DESC

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrateda_srchuserlist_del;
-- +goose StatementEnd
