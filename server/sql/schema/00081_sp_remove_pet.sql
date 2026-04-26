-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_RemovePet.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemovePet.sql
--
-- Deletes pets matching name_id (NOT id) AND char_id. The original SP's
-- commented branch used `id = @nId` but the active branch matches by
-- name_id — i.e. "remove all instances of pet catalogue X owned by char Y".
-- We preserve this verbatim (TODO: the original behaviour seems suspicious
-- because slots are not unique by name_id; revisit when client semantics
-- are fully reverse-engineered).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removepet(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removepet(
    _name_id BIGINT,
    _char_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- TODO: original NCSoft SP matches by name_id rather than id; appears
    -- intentional to delete all rows of a pet catalogue at once. Preserved.
    DELETE FROM user_pet
     WHERE name_id = _name_id::INTEGER AND char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removepet(BIGINT, INTEGER);
-- +goose StatementEnd
