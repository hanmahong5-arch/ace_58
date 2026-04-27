-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetUserInstance.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetUserInstance.sql
-- Older sibling of SetUserInstance_20171122 (00026): same upsert semantics on
-- (char_id, world_id) but only persists 6 columns (no kina/item/spinel).
-- The 3 omitted columns retain their existing values on UPDATE.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserinstance(
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserinstance(
    _char_id          INTEGER,
    _world_id         INTEGER,
    _instance_id      INTEGER,
    _reentrance_time  INTEGER,
    _server_id        INTEGER,
    _count_variate    INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_instance (
        char_id, world_id, instance_id, reentrance_time, server_id, count_variate
    ) VALUES (
        _char_id, _world_id, _instance_id, _reentrance_time, _server_id, _count_variate
    )
    ON CONFLICT (char_id, world_id) DO UPDATE
       SET instance_id     = EXCLUDED.instance_id,
           reentrance_time = EXCLUDED.reentrance_time,
           server_id       = EXCLUDED.server_id,
           count_variate   = EXCLUDED.count_variate;
    -- Note: kina_increase/item_increase/spinel_increase intentionally untouched
    -- on UPDATE — older client binaries that call this 6-arg variant must not
    -- clobber columns set by the 9-arg _20171122 caller in a parallel session.
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserinstance(
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd
