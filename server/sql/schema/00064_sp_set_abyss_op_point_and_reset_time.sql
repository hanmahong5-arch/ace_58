-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_SetAbyssOPPointAndResetTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_SetAbyssOPPointAndResetTime.sql
--
-- Upsert the per-race objective-point cache. Mirrors the IF EXISTS / UPDATE
-- ELSE INSERT pattern with PG INSERT … ON CONFLICT for atomicity.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssoppointandresettime(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setabyssoppointandresettime(
    _race              INTEGER,
    _quest             INTEGER,
    _fortress          INTEGER,
    _artifact          INTEGER,
    _basecamp          INTEGER,
    _op_object         INTEGER,
    _raid_object       INTEGER,
    _ownership_object  INTEGER,
    _next_reset_time   INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO abyss_op_point
           (race, quest, fortress, artifact, basecamp,
            op_object, raid_object, ownership_object, next_reset_time)
    VALUES (_race::SMALLINT, _quest, _fortress, _artifact, _basecamp,
            _op_object, _raid_object, _ownership_object, _next_reset_time)
    ON CONFLICT (race) DO UPDATE
        SET quest             = EXCLUDED.quest,
            fortress          = EXCLUDED.fortress,
            artifact          = EXCLUDED.artifact,
            basecamp          = EXCLUDED.basecamp,
            op_object         = EXCLUDED.op_object,
            raid_object       = EXCLUDED.raid_object,
            ownership_object  = EXCLUDED.ownership_object,
            next_reset_time   = EXCLUDED.next_reset_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setabyssoppointandresettime(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
