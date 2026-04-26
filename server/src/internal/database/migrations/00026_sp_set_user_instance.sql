-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetUserInstance_20171122.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetUserInstance_20171122.sql
-- Upsert on (char_id, world_id). T-SQL uses IF EXISTS+UPDATE/ELSE INSERT;
-- PG idiom is INSERT ... ON CONFLICT DO UPDATE.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserinstance_20171122(
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserinstance_20171122(
    _char_id          INTEGER,
    _world_id         INTEGER,
    _instance_id      INTEGER,
    _reentrance_time  INTEGER,
    _server_id        INTEGER,
    _count_variate    INTEGER,
    _kina_increase    INTEGER,
    _item_increase    INTEGER,
    _spinel_increase  INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_instance (
        char_id, world_id, instance_id, reentrance_time, server_id,
        count_variate, kina_increase, item_increase, spinel_increase
    ) VALUES (
        _char_id, _world_id, _instance_id, _reentrance_time, _server_id,
        _count_variate, _kina_increase, _item_increase, _spinel_increase
    )
    ON CONFLICT (char_id, world_id) DO UPDATE
       SET instance_id      = EXCLUDED.instance_id,
           reentrance_time  = EXCLUDED.reentrance_time,
           server_id        = EXCLUDED.server_id,
           count_variate    = EXCLUDED.count_variate,
           kina_increase    = EXCLUDED.kina_increase,
           item_increase    = EXCLUDED.item_increase,
           spinel_increase  = EXCLUDED.spinel_increase;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserinstance_20171122(
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd
