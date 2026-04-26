-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_GetAbyssGuildRank.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_GetAbyssGuildRank.sql
--
-- Returns the cached top-50 guild abyss snapshot.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssguildrank();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssguildrank()
RETURNS TABLE (
    out_rank        INTEGER,
    out_old_rank    INTEGER,
    out_id          INTEGER,
    out_race        SMALLINT,
    out_level       INTEGER,
    out_cnt         INTEGER,
    out_point       BIGINT,
    out_name        TEXT,
    out_updatetime  BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT  arr.rank,
            arr.old_rank,
            arr.id,
            arr.race,
            arr.level,
            arr.cnt,
            arr.point,
            arr.name,
            arr.updatetime
      FROM abyss_region_ranking AS arr
     ORDER BY arr.race, arr.rank;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssguildrank();
-- +goose StatementEnd
