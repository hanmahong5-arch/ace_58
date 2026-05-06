-- AionCore 5.8 — Sprint 1.1a batch 1 port: aion_SetUserBMPack (cash-shop pack upsert).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetUserBMPack.sql
-- Original (T-SQL):
--   IF EXISTS (SELECT char_id FROM user_bm_pack(updlock)
--              WHERE char_id = @char_id AND pack_type = @pack_type)
--       UPDATE user_bm_pack
--          SET pack_state = @pack_state, expiration_time = @expiration_time
--        WHERE char_id = @char_id AND pack_type = @pack_type
--   ELSE
--       INSERT user_bm_pack(char_id, pack_type, pack_state, expiration_time)
--       VALUES (@char_id, @pack_type, 1, @expiration_time)
--
-- ASYMMETRIC ON PURPOSE: the original NCSoft SP forces pack_state=1 on INSERT
-- regardless of the caller-supplied @pack_state, while UPDATE honours the
-- caller's value. This mirrors the cash-shop lifecycle: a brand-new pack must
-- always start at state=1 (未開封 unopened) — only later transitions can move
-- it to 2/3/…. The companion 00141_sp_get_user_bm_pack_list.sql relies on
-- this invariant to render the "your unopened packs" tab correctly.
--
-- We preserve the asymmetry exactly. Translating to ON CONFLICT DO UPDATE is
-- the idiomatic PG path; (char_id, pack_type) is the natural unique key. The
-- (updlock) hint becomes implicit row-level lock under PG's MVCC.
--
-- The function is VOID — callers don't need to know whether it took the INSERT
-- or UPDATE branch (matches the T-SQL contract of returning no resultset).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserbmpack(INTEGER, SMALLINT, SMALLINT, INTEGER);
DROP FUNCTION IF EXISTS aion_setuserbmpack(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserbmpack(
    _char_id          INTEGER,
    _pack_type        INTEGER,
    _pack_state       INTEGER,
    _expiration_time  INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_bm_pack
        (char_id, pack_type, pack_state, expiration_time)
    VALUES
        (_char_id, _pack_type::SMALLINT, 1::SMALLINT, _expiration_time)
    ON CONFLICT (char_id, pack_type) DO UPDATE
        SET pack_state      = _pack_state::SMALLINT,
            expiration_time = _expiration_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserbmpack(INTEGER, INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
