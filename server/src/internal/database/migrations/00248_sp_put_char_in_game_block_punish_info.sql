-- AionCore 5.8 — Sprint 1.1a batch 22 port: aion_PutCharInGameBlockPunishInfo
-- (record a new in-game punishment / mute / kick session).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutCharInGameBlockPunishInfo.sql
-- Original (T-SQL):
--   UPDATE user_punishment
--      SET status = 1, cancel_date = GetDate()
--    WHERE account_id = @accountId
--      AND char_id    = @characterId
--      AND punish_code = @punishCode
--      AND status = 0
--
--   INSERT INTO user_punishment(account_id, char_id, play_block, status,
--                               punish_code, start_date, end_date,
--                               remain_minute, punish_reason)
--   VALUES (@accountId, @characterId, 0, 0, @punishCode, GetDate(),
--           DATEADD(minute, @remainMin, GetDate()), @remainMin, @punishReason)
--
-- Schema:
--   user_punishment is a NEW table introduced by this batch. Domain has not
--   been touched before — contrast with user_block (block-list, 00072) and
--   user_serial_killer (PvP punish, future port). The shape mirrors the
--   NCSoft AionWorldLive.dbo.user_punishment columns referenced by the
--   sister SPs (Get/Set CharInGameBlockPunishInfo, GetCharPlayBlockPunishInfo).
--
-- Translation notes:
--   * Two-statement body translates to two SQL statements inside one plpgsql
--     body — atomic at SP-call granularity. NCSoft does NOT wrap them in a
--     transaction; we do not either (goose/pgx already wraps the SP call in
--     a transaction by default, which is a strictly safer envelope).
--   * GetDate() → NOW() (PG TIMESTAMPTZ). NCSoft GetDate() returns local
--     server time without TZ; PG NOW() returns TIMESTAMPTZ with TZ. The
--     calling Lua treats both as opaque — no TZ-sensitive logic in this SP.
--   * DATEADD(minute, @remainMin, GetDate()) → NOW() + (_remain_min || ' minutes')::INTERVAL.
--     We keep @remainMin caller-supplied (no clamp; NCSoft accepts negative
--     values which produce an end_date BEFORE start_date — pinned).
--   * nvarchar(200) → TEXT (PG has no length-bound varchar; NCSoft client
--     truncates before send).
--   * `play_block` defaults to 0 in the INSERT (NCSoft hardcoded). Pinned.
--   * `status` lifecycle: 0 = active, 1 = cancelled. The UPDATE-then-INSERT
--     pattern means a new punishment of the same code AUTO-CANCELS the
--     prior active one (cancel_date = NOW()). Pinned.
--
-- Bug-for-bug:
--   * If the same (account_id, char_id, punish_code) has multiple active
--     rows (status=0), all of them are cancelled at once by the UPDATE.
--     NCSoft never enforced uniqueness; we do not either. Pinned.
--   * `id` is BIGSERIAL — analogous to NCSoft IDENTITY. Caller does not
--     read it back (no RETURNING in the original).
--   * No FK on account_id / char_id. Orphan-tolerant.
--   * Negative remain_minute produces end_date < start_date. Pinned: NCSoft
--     uses this as a sentinel meaning "instantly expired".
--
-- Used by:
--   scripts/handlers/gm_apply_punishment.lua    -- GM-issued mute / kick
--   scripts/lib/punishment.lua                  -- shared write helper

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_punishment (
    id            BIGSERIAL    PRIMARY KEY,
    account_id    INTEGER      NOT NULL,
    char_id       INTEGER      NOT NULL,
    play_block    SMALLINT     NOT NULL DEFAULT 0,
    status        SMALLINT     NOT NULL DEFAULT 0, -- 0=active, 1=cancelled
    punish_code   INTEGER      NOT NULL,
    start_date    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    end_date      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    cancel_date   TIMESTAMPTZ  NULL,
    remain_minute INTEGER      NOT NULL DEFAULT 0,
    punish_reason TEXT         NOT NULL DEFAULT ''
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_punishment_char_active
    ON user_punishment (account_id, char_id, punish_code)
    WHERE status = 0;
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcharingameblockpunishinfo(INTEGER, INTEGER, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _account_id    : account that owns the char (paired with char_id for double check)
-- _character_id  : target char (the one being punished)
-- _punish_code   : enum slot — NCSoft uses small integer space (mute=1, kick=2, ...)
-- _remain_min    : minutes until expiry; negative is sentinel "instantly expired"
-- _punish_reason : free-form GM reason (NVARCHAR(200) → TEXT)
CREATE OR REPLACE FUNCTION aion_putcharingameblockpunishinfo(
    _account_id    INTEGER,
    _character_id  INTEGER,
    _punish_code   INTEGER,
    _remain_min    INTEGER,
    _punish_reason TEXT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    -- Step 1: cancel any prior ACTIVE punishment with the same code.
    -- T-SQL `status = 0` (active) → `status := 1` + cancel_date = now.
    UPDATE user_punishment
       SET status      = 1,
           cancel_date = NOW()
     WHERE account_id  = _account_id
       AND char_id     = _character_id
       AND punish_code = _punish_code
       AND status      = 0;

    -- Step 2: insert the new punishment row. play_block hardcoded 0,
    -- status hardcoded 0 (active), end_date computed from _remain_min.
    INSERT INTO user_punishment
        (account_id, char_id, play_block, status, punish_code,
         start_date, end_date, remain_minute, punish_reason)
    VALUES
        (_account_id, _character_id, 0, 0, _punish_code,
         NOW(), NOW() + make_interval(mins => _remain_min),
         _remain_min, _punish_reason);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcharingameblockpunishinfo(INTEGER, INTEGER, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_punishment_char_active;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_punishment;
-- +goose StatementEnd
