-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetInstanceDungeonValidityTerm.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInstanceDungeonValidityTerm.sql
--
-- Sibling of GetInstanceDungeonValidityTermList (00113): empty NCSoft body.
-- We provide a no-op so any caller bound to the old name resolves cleanly.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstancedungeonvaliditytermlist();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstancedungeonvaliditytermlist()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Empty body verbatim from T-SQL.
    RETURN;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstancedungeonvaliditytermlist();
-- +goose StatementEnd
