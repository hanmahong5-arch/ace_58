-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_DeleteFactionFriendship.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteFactionFriendship.sql
--
-- Soft-delete: the original SP's DELETE branch is commented out and only
-- jointime = 0 is set. Preserved verbatim.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefactionfriendship(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletefactionfriendship(
    _char_id    INTEGER,
    _faction_id SMALLINT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_faction_friendship
       SET jointime = 0
     WHERE char_id = _char_id AND faction_id = _faction_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefactionfriendship(INTEGER, SMALLINT);
-- +goose StatementEnd
