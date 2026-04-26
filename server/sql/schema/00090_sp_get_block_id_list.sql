-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetBlockIdList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetBlockIdList.sql
--
-- Returns just the block_id column (used by the gateway when checking incoming
-- whisper / friend-request packets — no need for the comment column).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblockidlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getblockidlist(
    _char_id INTEGER
)
RETURNS TABLE (
    out_block_id INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT block_id FROM user_block WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getblockidlist(INTEGER);
-- +goose StatementEnd
