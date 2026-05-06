-- AionCore 5.8 — Sprint 1.1a batch 1 port: aion_GetUserBMPackList (cash-shop pack listing).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserBMPackList.sql
-- Original (T-SQL):
--   SELECT pack_type, expiration_time
--   FROM user_bm_pack
--   WHERE char_id = @char_id AND pack_state = @pack_state
--
-- BM = "Black Market" / 商城 (NCSoft naming). Each row records a cash-shop
-- consumable pack the player has purchased; pack_state encodes the lifecycle
-- (1=未開封 unopened, 2=opened/active, 3=expired, …); expiration_time is a
-- 32-bit Unix epoch second.
--
-- The companion SETter (00142_sp_set_user_bm_pack.sql) inserts initial rows
-- with state=1 (forced by the original ELSE branch); higher states arrive
-- through other un-ported SPs that close out / refresh packs. Filtering by
-- (char_id, pack_state) lets the UI build "your unopened packs" / "your
-- active packs" lists cheaply.
--
-- This migration is the first to need user_bm_pack, so we create the table
-- here. tinyint in NCSoft becomes SMALLINT in PG (1 byte vs 2 bytes — the
-- engine never reads more than 0..255 so it's a non-issue).

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_bm_pack (
    char_id          INTEGER  NOT NULL,
    pack_type        SMALLINT NOT NULL,
    pack_state       SMALLINT NOT NULL DEFAULT 1,
    expiration_time  INTEGER  NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, pack_type)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_bm_pack_char_state
    ON user_bm_pack (char_id, pack_state);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserbmpacklist(INTEGER, SMALLINT);
DROP FUNCTION IF EXISTS aion_getuserbmpacklist(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- pack_state is INTEGER on the wire (Lua/Go pass plain int) and cast at the
-- comparison site; this avoids the caller having to remember the SMALLINT
-- conversion just to query the table.
CREATE OR REPLACE FUNCTION aion_getuserbmpacklist(
    _char_id    INTEGER,
    _pack_state INTEGER
)
RETURNS TABLE (
    pack_type        SMALLINT,
    expiration_time  INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT bp.pack_type, bp.expiration_time
          FROM user_bm_pack bp
         WHERE bp.char_id    = _char_id
           AND bp.pack_state = _pack_state::SMALLINT
         ORDER BY bp.pack_type ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserbmpacklist(INTEGER, INTEGER);
DROP TABLE IF EXISTS user_bm_pack;
-- +goose StatementEnd
