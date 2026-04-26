-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_GetAbyssRankingNew.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_GetAbyssRankingNew.sql
--
-- Returns top-N abyss-rank rows for one server+race combo, joined to
-- user_data (for user_id/gender) and guild (for legion name).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssrankingnew(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssrankingnew(
    _server_id INTEGER,
    _race      INTEGER,
    _num       INTEGER
)
RETURNS TABLE (
    out_abyss_ranking INTEGER,
    out_char_id       INTEGER,
    out_user_id       TEXT,
    out_class         SMALLINT,
    out_gender        BOOLEAN,
    out_lev           INTEGER,
    out_abyss_point   BIGINT,
    out_gp            BIGINT,
    out_update_time   BIGINT,
    out_guild_name    TEXT,
    out_old_ranking   INTEGER
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    _ut BIGINT;
BEGIN
    SELECT MAX(ar.update_time) INTO _ut
      FROM abyss_ranking AS ar
     WHERE ar.race      = _race::SMALLINT
       AND ar.server_id = _server_id;

    IF _ut IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT  ar.abyss_ranking,
            ar.char_id,
            ud.user_id,
            ar.class,
            ud.gender,
            ar.lev,
            ar.abyss_point,
            ar.gp,
            ar.update_time,
            COALESCE(g.name, ''),
            ar.old_ranking
      FROM abyss_ranking AS ar
      JOIN user_data AS ud ON ar.char_id  = ud.char_id
      LEFT JOIN guild AS g ON ar.guild_id = g.id
     WHERE ar.update_time = _ut
       AND ar.race        = _race::SMALLINT
       AND ar.server_id   = _server_id
     ORDER BY ar.abyss_ranking
     LIMIT _num;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssrankingnew(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
