-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchAbyssRanking.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssranking(_char_id TEXT, _update_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	



			declare _last_update_time int

			SELECT max(update_time) INTO _last_update_time from abyss_ranking



			select abyss_ranking, abyss_point, update_time, rank, rank_updatedate, gp

			from abyss_ranking (nolock)

			where char_id = _char_id and update_time = _last_update_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchabyssranking;
-- +goose StatementEnd
