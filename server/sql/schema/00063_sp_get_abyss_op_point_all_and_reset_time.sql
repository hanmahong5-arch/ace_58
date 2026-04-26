-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_GetAbyssOPPointAllAndResetTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_GetAbyssOPPointAllAndResetTime.sql
--
-- Dump every row of the abyss_op_point cache (one per race).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssoppointallandresettime();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getabyssoppointallandresettime()
RETURNS TABLE (
    out_race              SMALLINT,
    out_quest             INTEGER,
    out_fortress          INTEGER,
    out_artifact          INTEGER,
    out_basecamp          INTEGER,
    out_op_object         INTEGER,
    out_raid_object       INTEGER,
    out_ownership_object  INTEGER,
    out_next_reset_time   INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT  aop.race,
            aop.quest,
            aop.fortress,
            aop.artifact,
            aop.basecamp,
            aop.op_object,
            aop.raid_object,
            aop.ownership_object,
            aop.next_reset_time
      FROM abyss_op_point AS aop;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getabyssoppointallandresettime();
-- +goose StatementEnd
