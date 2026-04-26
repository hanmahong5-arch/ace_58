-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_PutCanMakeSticker_20131202.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutCanMakeSticker_20131202.sql
--
-- Upsert: insert (char_id, can_make_sticker, login_time) on first call;
-- subsequently only refresh login_time. NOTE: the original SP does NOT update
-- can_make_sticker on the UPDATE branch — we preserve that quirk verbatim.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcanmakesticker_20131202(INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcanmakesticker_20131202(
    _char_id           INTEGER,
    _can_make_sticker  SMALLINT,
    _login_time        INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_app_installation (char_id, can_make_sticker, login_time)
    VALUES (_char_id, _can_make_sticker, _login_time)
    ON CONFLICT (char_id) DO UPDATE
        SET login_time = EXCLUDED.login_time;
        -- NOTE: NCSoft does NOT refresh can_make_sticker on UPDATE — verbatim.
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcanmakesticker_20131202(INTEGER, SMALLINT, INTEGER);
-- +goose StatementEnd
