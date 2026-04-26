-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetAbyssRankingNew.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssrankingnew(_server_id INTEGER, _race INTEGER, _num INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	DECLARE _update_time BIGINT

	_update_time := (SELECT max(update_time) FROM abyss_ranking WHERE race = _race and server_id = _server_id)



	SELECT TOP(_num) abyss_ranking, abyss_ranking.char_id, user_data.user_id, abyss_ranking.class, user_data.gender, abyss_ranking.lev, abyss_ranking.abyss_point, abyss_ranking.gp, update_time, COALESCE(guild.name, ''), old_ranking

	FROM abyss_ranking(nolock)

	JOIN user_data with (nolock) on abyss_ranking.char_id = user_data.char_id

	LEFT JOIN guild with (nolock) on abyss_ranking.guild_id = guild.id

	WHERE update_time = _update_time 

	AND abyss_ranking.race = _race

	AND abyss_ranking.server_id = _server_id

	ORDER BY abyss_ranking



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssrankingnew;
-- +goose StatementEnd
