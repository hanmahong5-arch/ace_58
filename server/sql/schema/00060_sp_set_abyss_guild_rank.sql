-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_SetAbyssGuildRank.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_SetAbyssGuildRank.sql
--
-- Recompute the top-50 guild abyss leaderboard for a single race:
--   1. snapshot current guild.rank into guild.old_rank
--   2. zero out guild.rank for the race
--   3. assign 1..50 by point desc / point_max_time asc / id desc
--   4. rebuild abyss_region_ranking from guild + per-guild member count
--
-- The original T-SQL uses `UPDATE ... FROM (SELECT TOP 50 RANK() OVER ...)`
-- which PG supports via `UPDATE ... FROM (subquery)`. The RANK() window also
-- ports cleanly. We keep the same point_max_time tie-break for parity.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssguildrank(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssguildrank(_race INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    _now_unix BIGINT := EXTRACT(EPOCH FROM NOW())::BIGINT;
BEGIN
    -- (1) snapshot rank → old_rank for race
    UPDATE guild AS g
       SET old_rank = g.rank
     WHERE g.race = _race;

    -- (2) zero rank for race
    UPDATE guild AS g
       SET rank = 0
     WHERE g.race = _race;

    -- (3) re-assign top-50 ranks via window function.
    --     PG: WITH cte AS (...) UPDATE ... FROM cte ...
    WITH ranklist AS (
        SELECT  g.id,
                RANK() OVER (
                    ORDER BY g.point DESC,
                             g.point_max_time ASC,
                             g.id DESC
                ) AS rnk
          FROM guild AS g
         WHERE g.race = _race
         ORDER BY g.point DESC, g.point_max_time ASC, g.id DESC
         LIMIT 50
    )
    UPDATE guild AS g
       SET rank = rl.rnk::INTEGER
      FROM ranklist AS rl
     WHERE g.id = rl.id;

    -- (4) rebuild snapshot table.
    DELETE FROM abyss_region_ranking;

    INSERT INTO abyss_region_ranking
           (rank, old_rank, id, race, level, cnt, point, name, updatetime)
    SELECT  g.rank,
            g.old_rank,
            g.id,
            g.race,
            g.level,
            COALESCE(uc.cnt, 0)::INTEGER,
            g.point,
            g.name,
            _now_unix
      FROM guild AS g
      LEFT JOIN (
            SELECT  ud.guild_id,
                    COUNT(*)::INTEGER AS cnt
              FROM user_data AS ud
             WHERE ud.guild_id <> 0
             GROUP BY ud.guild_id
           ) AS uc ON g.id = uc.guild_id
     WHERE g.rank > 0
       AND g.rank <= 50
     ORDER BY g.race, g.rank;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssguildrank(INTEGER);
-- +goose StatementEnd
