-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_LegionDominionDA_SrchOwnerInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_legiondominionda_srchownerinfo(_world_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



			DECLARE	_lastest_take_over_time bigint

			_lastest_take_over_time := COALESCE((select max(take_over_processed_time) from legion_dominion_rankings where server_id=_world_id), 0)



			SELECT	legion_id, COALESCE(g.name, 'unknown') as legion_name, dominion_id, score, played_time_in_sec, game_end_time, take_over_processed_time, server_id

			FROM (

				SELECT	ROW_NUMBER() OVER (partition by dominion_id order by score desc, played_time_in_sec asc, game_end_time asc) as num, *

				FROM	legion_dominion_rankings d (nolock)

				WHERE	take_over_processed_time=_lastest_take_over_time

				AND		dominion_id != 0

				AND		server_id = _world_id

			) x

			LEFT JOIN guild g (nolock) on x.legion_id = g.id

			WHERE	x.num = 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_legiondominionda_srchownerinfo;
-- +goose StatementEnd
