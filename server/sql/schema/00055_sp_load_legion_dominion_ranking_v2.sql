-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_LoadLegionDominionRankingV2.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_LoadLegionDominionRankingV2.sql
--
-- For one in-flight (take_over_processed_time = 0) cycle of a dominion on a
-- given server, return the per-legion score row joined to guild cosmetics.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionrankingv2(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionrankingv2(
    _dominion_id INTEGER,
    _server_id   INTEGER
)
RETURNS TABLE (
    out_legion_id          INTEGER,
    out_race               SMALLINT,
    out_master_id          INTEGER,
    out_emblem_img_version SMALLINT,
    out_emblem_bgcolor     INTEGER,
    out_name               TEXT,
    out_score              INTEGER,
    out_played_time_in_sec INTEGER,
    out_game_end_time      BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT  ldr.legion_id,
            COALESCE(g.race, 0)::SMALLINT,
            COALESCE(g.master_id, 0),
            COALESCE(g.emblem_img_version, 0)::SMALLINT,
            COALESCE(g.emblem_bgcolor, 0),
            COALESCE(g.name, 'unknown'),
            ldr.score,
            ldr.played_time_in_sec,
            ldr.game_end_time
      FROM legion_dominion_rankings AS ldr
      LEFT JOIN guild AS g ON ldr.legion_id = g.id
     WHERE ldr.take_over_processed_time = 0
       AND ldr.dominion_id              = _dominion_id
       AND ldr.server_id                = _server_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionrankingv2(INTEGER, INTEGER);
-- +goose StatementEnd
