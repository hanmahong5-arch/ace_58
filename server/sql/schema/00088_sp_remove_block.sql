-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_RemoveBlock.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_RemoveBlock.sql

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeblock(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_removeblock(
    _char_id  INTEGER,
    _block_id INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_block
     WHERE char_id = _char_id AND block_id = _block_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_removeblock(INTEGER, INTEGER);
-- +goose StatementEnd
