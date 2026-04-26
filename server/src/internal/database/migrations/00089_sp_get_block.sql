-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetBlock.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetBlock.sql
--
-- Inner-joins user_block with user_data to expose the blocked party's user_id
-- alongside the comment.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblock(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getblock(
    _char_id INTEGER
)
RETURNS TABLE (
    out_block_id INTEGER,
    out_user_id  TEXT,
    out_comment  TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT b.block_id, d.user_id, b.comment
      FROM user_block b
      JOIN user_data d ON b.block_id = d.char_id
     WHERE b.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblock(INTEGER);
-- +goose StatementEnd
