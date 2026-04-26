-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_SetGuildIntro.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetGuildIntro.sql
-- Updates the legion's introduction line (≤32 chars in T-SQL, but PG TEXT
-- has no enforced limit; the gateway truncates client-side).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildintro(INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildintro(_guild_id INTEGER, _intro TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE guild SET intro = _intro WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildintro(INTEGER, TEXT);
-- +goose StatementEnd
