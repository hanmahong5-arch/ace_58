-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_ProcessLegionDominionTakeOver.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_ProcessLegionDominionTakeOver.sql
--
-- Atomic dominion take-over commit:
--   1. compute the lastest take_over_processed_time
--   2. if the caller's _take_over_time is newer than that:
--      a. insert a sentinel row with the new processed_time (binds the cycle)
--      b. stamp processed_time on every in-flight (=0) row of that server
--      c. evict any rows older than 30 days for hygiene

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_processlegiondominiontakeover(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_processlegiondominiontakeover(
    _take_over_time BIGINT,
    _server_id      INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    _lastest BIGINT;
BEGIN
    SELECT COALESCE(MAX(take_over_processed_time), 0)
      INTO _lastest
      FROM legion_dominion_rankings
     WHERE server_id = _server_id;

    IF _take_over_time > 0 AND _lastest < _take_over_time THEN
        -- Sentinel marker (legion_id=0, dominion_id=0) records the cycle close.
        INSERT INTO legion_dominion_rankings
               (legion_id, dominion_id, score, played_time_in_sec, game_end_time,
                take_over_processed_time, server_id)
        VALUES (0, 0, 0, 0, 0, _take_over_time, _server_id);

        UPDATE legion_dominion_rankings
           SET take_over_processed_time = _take_over_time
         WHERE take_over_processed_time = 0
           AND server_id                = _server_id;

        -- 30 days = 30*24*60*60 = 2,592,000 seconds
        DELETE FROM legion_dominion_rankings
         WHERE take_over_processed_time < (_take_over_time - 2592000)
           AND server_id                = _server_id;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_processlegiondominiontakeover(BIGINT, INTEGER);
-- +goose StatementEnd
