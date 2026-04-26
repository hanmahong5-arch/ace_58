-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetCanMakeSticker.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCanMakeSticker.sql

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcanmakesticker(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcanmakesticker(
    _char_id INTEGER
)
RETURNS TABLE (
    out_can_make_sticker SMALLINT,
    out_login_time       INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT can_make_sticker, COALESCE(login_time, 0)::INTEGER
      FROM user_app_installation
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcanmakesticker(INTEGER);
-- +goose StatementEnd
