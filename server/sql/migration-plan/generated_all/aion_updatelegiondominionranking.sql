-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateLegionDominionRanking.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatelegiondominionranking(_legion_id INTEGER, _legion_name TEXT, _dominion_id INTEGER, _score INTEGER, _played_time INTEGER, _game_end_time BIGINT, _server_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if NOT EXISTS(SELECT _dominion_id FROM legion_dominion_rankings(updlock) WHERE legion_id=_legion_id and dominion_id=_dominion_id and take_over_processed_time=0 and server_id=_server_id)

begin

	INSERT legion_dominion_rankings (legion_id, dominion_id, score, played_time_in_sec, game_end_time, take_over_processed_time, server_id) VALUES (_legion_id, _dominion_id, _score, _played_time, _game_end_time, 0, _server_id)

end

else

begin

	UPDATE legion_dominion_rankings SET score=_score, played_time_in_sec=_played_time, game_end_time=_game_end_time where legion_id=_legion_id and dominion_id=_dominion_id and take_over_processed_time=0 and server_id=_server_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatelegiondominionranking;
-- +goose StatementEnd
