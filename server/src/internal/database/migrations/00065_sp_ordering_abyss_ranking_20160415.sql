-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_OrderingAbyssRanking_20160415.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_OrderingAbyssRanking_20160415.sql
--
-- Periodic abyss-ranking snapshot:
--   1. evict zero-GP user_gp_data rows
--   2. insert top-N rows ordered by (gp_sum desc, abyss_point desc, lev desc)
--      with last_logout_time within 30 days and the 4-week sliding-GP filter.
--   3. backfill old_ranking from the previous snapshot
--   4. evict snapshots older than 4 weeks
--   5. piggy-back the guild rank refresh
--
-- _is_special_svr=1 disables the 4-week sliding GP filter (special-rules realm).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_orderingabyssranking_20160415(INTEGER, INTEGER, INTEGER, BIGINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_orderingabyssranking_20160415(
    _is_special_svr        INTEGER,
    _server_id             INTEGER,
    _race                  INTEGER,
    _time                  BIGINT,
    _num                   INTEGER,
    _this_week_update_time INTEGER,
    _recent_gp_min         INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    _prev_update_time BIGINT;
BEGIN
    -- previous snapshot's update_time for old_ranking backfill.
    SELECT COALESCE(MAX(ar.update_time), 0)
      INTO _prev_update_time
      FROM abyss_ranking AS ar
     WHERE ar.race      = _race::SMALLINT
       AND ar.server_id = _server_id;

    IF _is_special_svr = 0 THEN
        -- evict no-GP rows so they don't drag down the join cardinality.
        DELETE FROM user_gp_data AS gp
         WHERE gp.glory_point        <= 0
           AND gp.ownership_bonus_gp <= 0;

        INSERT INTO abyss_ranking
               (abyss_ranking, server_id, update_time, char_id, abyss_point,
                race, class, lev, guild_id, rank, old_ranking, gp, rank_updatedate)
        SELECT  RANK() OVER (
                    ORDER BY (COALESCE(gp.glory_point, 0) + COALESCE(gp.ownership_bonus_gp, 0)) DESC,
                             ud.abyss_point DESC,
                             ud.lev DESC,
                             ud.char_id ASC
                )::INTEGER,
                _server_id,
                _time,
                ud.char_id,
                ud.abyss_point,
                ud.race,
                ud.class,
                ud.lev,
                ud.guild_id,
                0, 0,
                (COALESCE(gp.glory_point, 0) + COALESCE(gp.ownership_bonus_gp, 0)),
                NULL
          FROM user_data AS ud
          LEFT OUTER JOIN user_gp_data AS gp ON ud.char_id = gp.char_id
         WHERE ud.race       = _race::SMALLINT
           AND ud.org_server = _server_id::SMALLINT
           AND (ud.delete_date = 0 OR ud.delete_date > _time)
           AND (DATE_PART('day', NOW() - ud.last_logout_time) < 30)
           -- 4-week sliding GP threshold: bucket compare_time vs request time.
           AND (
                CASE
                    WHEN ud.this_week_compare_time = _this_week_update_time
                      OR (_this_week_update_time / 86400) = (ud.this_week_compare_time / 86400)
                        THEN (ud.this_week_glory_point::BIGINT
                              + ud.last_week_glory_point
                              + ud.two_weeks_ago_glory_point
                              + ud.three_weeks_ago_glory_point)
                    WHEN ud.this_week_compare_time >= (_this_week_update_time - 604800)
                      OR ((_this_week_update_time / 86400) - 7) = (ud.this_week_compare_time / 86400)
                        THEN (ud.this_week_glory_point::BIGINT
                              + ud.last_week_glory_point
                              + ud.two_weeks_ago_glory_point)
                    WHEN ud.this_week_compare_time >= (_this_week_update_time - 1209600)
                      OR ((_this_week_update_time / 86400) - 14) = (ud.this_week_compare_time / 86400)
                        THEN (ud.this_week_glory_point::BIGINT + ud.last_week_glory_point)
                    WHEN ud.this_week_compare_time >= (_this_week_update_time - 1814400)
                      OR ((_this_week_update_time / 86400) - 21) = (ud.this_week_compare_time / 86400)
                        THEN ud.this_week_glory_point::BIGINT
                    ELSE 0
                END
           ) >= _recent_gp_min
         LIMIT _num;
    ELSE
        -- special-rules realm: no GP-window filter, simpler ordering by AP/lev.
        INSERT INTO abyss_ranking
               (abyss_ranking, server_id, update_time, char_id, abyss_point,
                race, class, lev, guild_id, rank, old_ranking, gp, rank_updatedate)
        SELECT  RANK() OVER (
                    ORDER BY ud.abyss_point DESC,
                             ud.lev DESC,
                             ud.char_id ASC
                )::INTEGER,
                _server_id,
                _time,
                ud.char_id,
                ud.abyss_point,
                ud.race,
                ud.class,
                ud.lev,
                ud.guild_id,
                0, 0,
                (COALESCE(gp.glory_point, 0) + COALESCE(gp.ownership_bonus_gp, 0)),
                NULL
          FROM user_data AS ud
          LEFT OUTER JOIN user_gp_data AS gp ON ud.char_id = gp.char_id
         WHERE ud.race       = _race::SMALLINT
           AND ud.org_server = _server_id::SMALLINT
           AND (ud.delete_date = 0 OR ud.delete_date > _time)
           AND (DATE_PART('day', NOW() - ud.last_logout_time) < 30)
         LIMIT _num;
    END IF;

    -- backfill old_ranking from the previous snapshot
    UPDATE abyss_ranking AS ar
       SET old_ranking = COALESCE((
                SELECT b.abyss_ranking
                  FROM abyss_ranking AS b
                 WHERE b.race        = _race::SMALLINT
                   AND b.server_id   = _server_id
                   AND b.update_time = _prev_update_time
                   AND b.char_id     = ar.char_id
                   AND b.rank        <> 0
                 LIMIT 1
           ), 0)
     WHERE ar.update_time = _time
       AND ar.race        = _race::SMALLINT
       AND ar.server_id   = _server_id;

    -- evict snapshots older than 4 weeks (2,419,200 sec).
    DELETE FROM abyss_ranking AS ar
     WHERE ar.update_time < (EXTRACT(EPOCH FROM NOW())::BIGINT - 2419200);

    -- refresh the guild rank cache for the same race.
    PERFORM aion_setabyssguildrank(_race);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_orderingabyssranking_20160415(INTEGER, INTEGER, INTEGER, BIGINT, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
