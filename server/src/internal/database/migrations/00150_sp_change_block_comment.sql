-- AionCore 5.8 — Sprint 1.1a batch 3 port: aion_ChangeBlockComment.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ChangeBlockComment.sql
-- Original (T-SQL):
--   UPDATE user_block SET comment = @Comment
--    WHERE char_id = @nCharId AND block_id = @nBlockId
--
-- Translation notes:
--   * user_block already carries `comment TEXT NOT NULL DEFAULT ''` from the
--     00072 PvE round-5 scaffold — no schema delta needed. The aion_AddBlock
--     SP already INSERTs comment-on-create; this SP just lets the player edit
--     it later from the social panel.
--   * Returns rows-affected (0 = no such pair, 1 = updated). T-SQL had no
--     return; PG-side Lua callers want the rowcount so they can avoid pushing
--     SM_BLOCK_RESPONSE refreshes when nothing changed.
--
-- Used by: scripts/handlers/cm_change_block_comment.lua (future).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_change_block_comment(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_change_block_comment(
    _char_id  INTEGER,
    _block_id INTEGER,
    _comment  TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    updated_cnt INTEGER;
BEGIN
    UPDATE user_block
       SET comment = _comment
     WHERE char_id  = _char_id
       AND block_id = _block_id;
    GET DIAGNOSTICS updated_cnt = ROW_COUNT;
    RETURN updated_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_change_block_comment(INTEGER, INTEGER, TEXT);
-- +goose StatementEnd
