-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_LoadLegionDominionLastestTakeOverTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_LoadLegionDominionLastestTakeOverTime.sql
--
-- Returns the most recent take-over-processed timestamp for the given server.
-- Used by ProcessLegionDominionTakeOver to detect whether a new cycle landed
-- since the last poll. T-SQL `RETURN <bigint>` translates to a single-column
-- single-row resultset in PG; we expose it as a function returning BIGINT.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionlastesttakeovertime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionlastesttakeovertime(_server_id INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql STABLE AS $$
DECLARE
    _lastest BIGINT;
BEGIN
    SELECT COALESCE(MAX(take_over_processed_time), 0)
      INTO _lastest
      FROM legion_dominion_rankings
     WHERE server_id = _server_id;
    RETURN _lastest;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionlastesttakeovertime(INTEGER);
-- +goose StatementEnd
