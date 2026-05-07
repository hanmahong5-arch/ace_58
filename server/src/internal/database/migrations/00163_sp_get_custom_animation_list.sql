-- AionCore 5.8 — Sprint 1.1a batch 5 port: aion_GetCustomAnimationList (login custom-emote hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCustomAnimationList.sql
-- Original (T-SQL):
--   SELECT animation_id, animation_type, expire_time, useState
--   FROM user_customAnimation
--   WHERE char_id=@nCharId AND expire_time > 0
--
-- Translation notes:
--   * NCSoft case-mixed table name `user_customAnimation` — folded to plain
--     `user_custom_animation` per PG identifier rules (snake-case is also
--     more idiomatic).
--   * Per-row state:
--       - animation_id    INT     : 5.8 client custom-anim catalog id
--       - animation_type  TINYINT : category (0=stance, 1=walk, 2=run, …)
--       - expire_time     BIGINT  : unix epoch seconds (0 = expired/inactive)
--       - useState        TINYINT : 0=owned-not-equipped, 1=equipped (NCSoft camelCase preserved-but-folded)
--   * `expire_time > 0` filter preserved verbatim — NCSoft semantics is
--     "rows with expire_time=0 are tombstones, hide them from the client".
--     Older 4.x clients used a DELETE-based purge; 5.x switched to soft
--     expiry to preserve customer-support audit trails. We preserve the
--     soft-expiry contract.
--   * Source column `useState` (camelCase) → PG `use_state` (snake). The
--     SP RETURNS TABLE column is named `use_state` to match PG conventions;
--     the on-the-wire byte is the same 1-byte value either way.
--   * animation_type / use_state are SMALLINT in PG (TINYINT doesn't exist
--     in PG; SMALLINT is the smallest int — same pattern as 00148 familiar).
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- custom-anim hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_custom_animation (
    char_id        INTEGER  NOT NULL,
    animation_id   INTEGER  NOT NULL,
    animation_type SMALLINT NOT NULL DEFAULT 0,
    expire_time    BIGINT   NOT NULL DEFAULT 0,
    use_state      SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, animation_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_custom_animation_char ON user_custom_animation(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcustomanimationlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcustomanimationlist(_char_id INTEGER)
RETURNS TABLE (
    animation_id   INTEGER,
    animation_type SMALLINT,
    expire_time    BIGINT,
    use_state      SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uca.animation_id, uca.animation_type, uca.expire_time, uca.use_state
          FROM user_custom_animation uca
         WHERE uca.char_id     = _char_id
           AND uca.expire_time > 0
         ORDER BY uca.animation_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcustomanimationlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_custom_animation_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_custom_animation;
-- +goose StatementEnd
