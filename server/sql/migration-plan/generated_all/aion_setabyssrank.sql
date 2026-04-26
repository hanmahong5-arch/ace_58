-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetAbyssRank.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssrank(_server_id INTEGER, _race INTEGER, _time BIGINT, _rank INTEGER, _min_ranking INTEGER, _max_ranking INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update abyss_ranking Set rank = _rank, rank_updatedate = NOW()

where	update_time = _time

	and race = _race

	and server_id = _server_id

	and abyss_ranking >= _min_ranking

	and abyss_ranking <= _max_ranking;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssrank;
-- +goose StatementEnd
