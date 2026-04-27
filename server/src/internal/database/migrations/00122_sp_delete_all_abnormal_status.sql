-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteAllAbnormalStatus.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAllAbnormalStatus.sql
--
-- T-SQL body:
--   DELETE FROM user_abnormal_status WHERE char_id=@nCharId
--
-- Wipes a character's persisted buffs/debuffs. Invoked at logout (so a
-- player cannot log out, drink a potion timer, then re-log to extend it)
-- and during the character-purge cascade.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallabnormalstatus(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteallabnormalstatus(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_abnormal_status WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteallabnormalstatus(INTEGER);
-- +goose StatementEnd
