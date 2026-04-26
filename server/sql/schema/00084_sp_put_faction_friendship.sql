-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_PutFactionFriendship.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutFactionFriendship.sql
--
-- Upsert: if (char_id, faction_id) exists → UPDATE jointime + friendship,
-- else INSERT a fresh row. PG ON CONFLICT keeps it atomic.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfactionfriendship(INTEGER, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfactionfriendship(
    _user_id    INTEGER,
    _faction_id SMALLINT,
    _point      INTEGER,
    _join_time  INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_faction_friendship (char_id, faction_id, friendship, jointime)
    VALUES (_user_id, _faction_id, _point, _join_time)
    ON CONFLICT (char_id, faction_id) DO UPDATE
        SET friendship = EXCLUDED.friendship,
            jointime   = EXCLUDED.jointime;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfactionfriendship(INTEGER, SMALLINT, INTEGER, INTEGER);
-- +goose StatementEnd
