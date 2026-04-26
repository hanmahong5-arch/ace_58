-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_SetAbyssRank.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_SetAbyssRank.sql
--
-- Bulk-stamp the `rank` column for all abyss_ranking rows whose abyss_ranking
-- (sequence number) falls in [_min,_max] for a given (server,race,update_time).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssrank(INTEGER, INTEGER, BIGINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssrank(
    _server_id     INTEGER,
    _race          INTEGER,
    _time          BIGINT,
    _rank          INTEGER,
    _min_ranking   INTEGER,
    _max_ranking   INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE abyss_ranking AS ar
       SET rank            = _rank,
           rank_updatedate = NOW()
     WHERE ar.update_time   = _time
       AND ar.race          = _race::SMALLINT
       AND ar.server_id     = _server_id
       AND ar.abyss_ranking >= _min_ranking
       AND ar.abyss_ranking <= _max_ranking;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssrank(INTEGER, INTEGER, BIGINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
