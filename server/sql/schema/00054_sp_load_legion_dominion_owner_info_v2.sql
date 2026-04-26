-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_LoadLegionDominionOwnerInfoV2.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_LoadLegionDominionOwnerInfoV2.sql
--
-- Per dominion territory, returns the winning legion's row from the snapshot
-- identified by _lastest_take_over_time (rank=1 by score desc, time asc).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionownerinfov2(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_loadlegiondominionownerinfov2(
    _lastest_take_over_time BIGINT,
    _server_id              INTEGER
)
RETURNS TABLE (
    out_dominion_id        INTEGER,
    out_legion_id          INTEGER,
    out_race               SMALLINT,
    out_master_id          INTEGER,
    out_emblem_img_version SMALLINT,
    out_emblem_bgcolor     INTEGER,
    out_name               TEXT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- Window-function rank-1 picker per dominion_id, joined to guild for cosmetic
    -- info. ISNULL(...) → COALESCE(...). T-SQL string literal 'unknown' kept verbatim.
    RETURN QUERY
    SELECT  ranked.dominion_id,
            ranked.legion_id,
            COALESCE(g.race, 0)::SMALLINT,
            COALESCE(g.master_id, 0),
            COALESCE(g.emblem_img_version, 0)::SMALLINT,
            COALESCE(g.emblem_bgcolor, 0),
            COALESCE(g.name, 'unknown')
      FROM (
            SELECT  ROW_NUMBER() OVER (
                        PARTITION BY ldr.dominion_id
                        ORDER BY ldr.score DESC,
                                 ldr.played_time_in_sec ASC,
                                 ldr.game_end_time ASC
                    ) AS rn,
                    ldr.dominion_id,
                    ldr.legion_id
              FROM legion_dominion_rankings AS ldr
             WHERE ldr.dominion_id <> 0
               AND ldr.take_over_processed_time = _lastest_take_over_time
           ) AS ranked
      LEFT JOIN guild AS g ON ranked.legion_id = g.id
     WHERE ranked.rn = 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_loadlegiondominionownerinfov2(BIGINT, INTEGER);
-- +goose StatementEnd
