-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_AddBlock.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddBlock.sql
--
-- Idempotent insert: only INSERT if the (char_id, block_id) row does not exist.
-- ON CONFLICT DO NOTHING is the natural PG translation.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addblock(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addblock(
    _char_id  INTEGER,
    _block_id INTEGER,
    _comment  TEXT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_block (char_id, block_id, comment)
    VALUES (_char_id, _block_id, _comment)
    ON CONFLICT (char_id, block_id) DO NOTHING;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addblock(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd
