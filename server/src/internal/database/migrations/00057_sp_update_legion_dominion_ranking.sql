-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_UpdateLegionDominionRanking.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_UpdateLegionDominionRanking.sql
--
-- Upsert a legion's score for the in-flight (take_over_processed_time=0)
-- cycle of a given dominion+server. _legion_name is accepted but not stored
-- (the original schema marked it deprecated: "/* 없어질 예정 */").

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatelegiondominionranking(INTEGER, TEXT, INTEGER, INTEGER, INTEGER, BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatelegiondominionranking(
    _legion_id     INTEGER,
    _legion_name   TEXT,        -- accepted but deprecated upstream
    _dominion_id   INTEGER,
    _score         INTEGER,
    _played_time   INTEGER,
    _game_end_time BIGINT,
    _server_id     INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Try update-first to mirror the T-SQL "if NOT EXISTS … insert / else update"
    -- pattern; the GET DIAGNOSTICS row count then decides whether to insert.
    UPDATE legion_dominion_rankings
       SET score              = _score,
           played_time_in_sec = _played_time,
           game_end_time      = _game_end_time
     WHERE legion_id                = _legion_id
       AND dominion_id              = _dominion_id
       AND take_over_processed_time = 0
       AND server_id                = _server_id;

    IF NOT FOUND THEN
        INSERT INTO legion_dominion_rankings
               (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
                take_over_processed_time, server_id)
        VALUES (_legion_id, _dominion_id, _score, _played_time, _game_end_time,
                0, _server_id);
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatelegiondominionranking(INTEGER, TEXT, INTEGER, INTEGER, INTEGER, BIGINT, INTEGER);
-- +goose StatementEnd
