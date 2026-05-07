-- AionCore 5.8 — Sprint 1.1a batch 14 port: aion_PutBingoCoin (bingo coin grant log).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutBingoCoin.sql
-- Original (T-SQL):
--   INSERT INTO user_bingo (guid, bingo_type, bingo_nameid, status, regdate,
--                           account_id, amount)
--   VALUES (@guid, @bingo_type, @bingo_nameid, @status, GETDATE(), @account_id, @amount)
--
-- Translation notes:
--   * Pure append-only INSERT — every coin grant is a fresh row, even if the
--     same (guid, bingo_type, bingo_nameid) tuple has appeared before. The
--     T-SQL has no UNIQUE/UPSERT guard; it is an audit log of bingo events.
--   * `regdate = GETDATE()` (T-SQL = SQL Server local clock) is replaced by
--     PG's `NOW()` (TIMESTAMPTZ). NCSoft stores it as a wall-clock DATETIME
--     without TZ; PG's TZ-aware variant makes round-tripping unambiguous.
--   * `guid` is the character row id (int). `account_id` is the account FK
--     (int). `amount` is SMALLINT — bingo coin grant deltas are tiny.
--   * Returns rows-affected (always 1 for normal flow); aids caller observability.
--
-- Bug-for-bug:
--   * No FK enforced (NCSoft's table is freestanding). Bingo events for a
--     deleted char are still logged — this is forensically correct.
--   * Duplicate inserts at the same wall-clock millisecond are allowed; the
--     audit trail intentionally preserves the rate of an event burst.
--
-- Used by:
--   scripts/handlers/cm_bingo_grant.lua  (Q3 — bingo entropy events)

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_bingo (
    id            BIGSERIAL    PRIMARY KEY,
    guid          INTEGER      NOT NULL,
    bingo_type    SMALLINT     NOT NULL,
    bingo_nameid  INTEGER      NOT NULL,
    status        SMALLINT     NOT NULL,
    regdate       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    account_id    INTEGER      NOT NULL,
    amount        SMALLINT     NOT NULL
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_bingo_guid       ON user_bingo(guid);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_bingo_account_id ON user_bingo(account_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbingocoin(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putbingocoin(
    _guid          INTEGER,
    _bingo_type    SMALLINT,
    _bingo_nameid  INTEGER,
    _status        SMALLINT,
    _account_id    INTEGER,
    _amount        SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure INSERT — no dedup, no UPSERT. NCSoft semantics: every grant is
    -- a fresh audit row.
    INSERT INTO user_bingo (
        guid, bingo_type, bingo_nameid, status, regdate, account_id, amount
    ) VALUES (
        _guid, _bingo_type, _bingo_nameid, _status, NOW(), _account_id, _amount
    );
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putbingocoin(INTEGER, SMALLINT, INTEGER, SMALLINT, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_bingo_account_id;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_bingo_guid;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_bingo;
-- +goose StatementEnd
