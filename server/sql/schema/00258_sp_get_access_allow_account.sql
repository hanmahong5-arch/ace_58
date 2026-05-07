-- AionCore 5.8 — Sprint 1.1a batch 24 port: aion_GetAccessAllowAccount
-- (whitelist enumeration: every account currently allowed past the gate).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetAccessAllowAccount.sql
-- Original (T-SQL):
--   select account_id, account_name from access_allow_account(nolock) where status=0;
--
-- Domain (`access_allow_account`, untouched before this batch):
--   NCSoft uses access_allow_account as a per-world allow-list during
--   maintenance windows / closed-beta phases / staff-only test shards. The
--   gateway gates each connect against this list when the world is in
--   "restricted" mode. status=0 marks an entry as live; status>0 is the
--   soft-delete / suspended set (NCSoft historical convention: status=1 =
--   "expired", status=2 = "revoked"; both excluded from the live read).
--   The world engine refreshes this list periodically — typically every
--   60s during a closed window — so a fresh GM grant takes effect within
--   one cycle without restarting the world.
--
-- Translation notes:
--   * Zero-parameter SP. RETURNS TABLE so a SELECT can iterate rows on the
--     Go side via pool.CallSP("aion_getaccessallowaccount").
--   * NOLOCK hint dropped — PostgreSQL MVCC gives the same dirty-read-style
--     "no locks taken" semantics for STABLE functions without the hint.
--   * status=0 hard-coded in the WHERE clause (not parameterised) to match
--     NCSoft contract exactly. If a future migration needs the suspended
--     set, write a separate SP rather than overload this one.
--   * Function declared STABLE — pure read, side-effect-free.
--   * Schema: access_allow_account table did not previously exist on the PG
--     side; we create it here with idempotent CREATE TABLE IF NOT EXISTS.
--     Schema mirrors NCSoft exactly:
--       account_id   INT        — PK; the AionAccountDB.account_id reference
--       account_name NVARCHAR   — kept as TEXT on PG side
--       status       SMALLINT   — 0=live / 1=expired / 2=revoked / >=3=reserved
--   * The (account_id) PK guarantees one allow-row per account; gameplay
--     code calling this SP relies on stable order of returned rows being
--     irrelevant — pinned (no ORDER BY).
--
-- Bug-for-bug:
--   * NCSoft does NOT bound status; values 3..MAX(SMALLINT) are silently
--     excluded by the status=0 filter — pinned (we keep the same broad
--     SMALLINT column, no CHECK constraint).
--   * Empty-set when no rows match; the gateway treats empty as "no
--     restrictions" — pinned (this matches a fresh world install with no
--     access list seeded).
--
-- Used by:
--   scripts/lib/access_control.lua  (refreshes whitelist cache on tick)
--   scripts/handlers/cm_enter_world.lua  (deny-by-default during restricted mode)

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS access_allow_account (
    account_id   INTEGER  PRIMARY KEY,
    account_name TEXT     NOT NULL DEFAULT '',
    status       SMALLINT NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getaccessallowaccount();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getaccessallowaccount()
RETURNS TABLE (
    account_id   INTEGER,
    account_name TEXT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT a.account_id, a.account_name
          FROM access_allow_account a
         WHERE a.status = 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getaccessallowaccount();
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS access_allow_account;
-- +goose StatementEnd
