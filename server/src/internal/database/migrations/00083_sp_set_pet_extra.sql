-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_SetPetExtra.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetPetExtra.sql
--
-- Updates the cosmetic columns: name + visual_data. Matches by user_pet.id and
-- char_id (uses the BIGSERIAL row id here, NOT name_id — NCSoft's intent is
-- "rename / reskin a specific instance"). Stamps change_info_time.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetextra(BIGINT, INTEGER, TEXT, BYTEA);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetextra(
    _id           BIGINT,
    _char_id      INTEGER,
    _name         TEXT,
    _visual_data  BYTEA
)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    cit BIGINT;
BEGIN
    cit := GetUnixtimeWithUTCAdjust(NOW(), 0);
    UPDATE user_pet
       SET name             = _name,
           visual_data      = _visual_data,
           change_info_time = cit
     WHERE id = _id AND char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetextra(BIGINT, INTEGER, TEXT, BYTEA);
-- +goose StatementEnd
