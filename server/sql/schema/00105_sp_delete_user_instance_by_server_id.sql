-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_DeleteUserInstanceByServerId.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteUserInstanceByServerId.sql
-- Wipes every instance entry tied to a given physical server_id, except those
-- whose world_id is in the protected lobby/tournament list. Used during
-- planned shard maintenance — the server unbinds players cleanly without
-- losing their tournament/arena slot.
--
-- Protected world_ids verbatim from NCSoft:
--   302350000 — generic instance lobby
--   302450000 — Tower of Challenge entrance
--   300360000 — Solo Arena 1v1 entry
--   302320000 — Templar Training Lobby
--   302390000 — 1v1 Tournament Lobby
--   300450000 — Party Tournament Lobby

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteuserinstancebyserverid(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteuserinstancebyserverid(_server_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_instance
     WHERE server_id = _server_id
       AND world_id NOT IN (302350000, 302450000, 300360000,
                            302320000, 302390000, 300450000);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteuserinstancebyserverid(INTEGER);
-- +goose StatementEnd
