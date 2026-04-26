-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_GetCharBuilder.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCharBuilder.sql
-- Returns the GM-builder flag (single CHAR column) for a char_id.
-- Used by the world server during character entry to decide whether to grant
-- GM/builder permissions on packets like CM_GM_COMMAND.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharbuilder(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharbuilder(_char_id INTEGER)
RETURNS TABLE (builder CHAR(1))
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT user_data.builder FROM user_data WHERE user_data.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharbuilder(INTEGER);
-- +goose StatementEnd
