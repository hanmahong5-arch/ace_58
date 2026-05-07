-- AionCore 5.8 — Sprint 1.1a batch 24 port: aion_GetVirtualAuthAccountId
-- (auxiliary auth path: account_id lookup by account_name from user_data).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetVirtualAuthAccountId.sql
-- Original (T-SQL):
--   SELECT TOP 1 account_id from user_data
--   where account_name = @strAccountName
--
-- Domain (`virtual_auth`, untouched before this batch):
--   NCSoft maintains a "virtual auth" path for cases where the gateway has
--   the account_name (a string entered at login or piped in via a launcher
--   handshake) but does NOT yet have the numeric account_id. The canonical
--   path is to call ap_verify_account against AionAccountDB, but that round
--   trip is heavy and acquires a lock on the auth shard; for many local
--   operations (e.g. checking whether an account already has a char on this
--   world, or warming the user_data side of session migration) the SP just
--   needs the integer id, not the password verification. This SP scrapes
--   the world-side user_data table for the first matching account_name and
--   returns the integer id — no password check.
--
-- Translation notes:
--   * SQL Server `SELECT TOP 1` → PostgreSQL `LIMIT 1`. NCSoft does not
--     provide an ORDER BY, which means TOP 1 returns an arbitrary row when
--     multiple chars share the same account_name (expected — many chars
--     per account, all share account_id, so any pick is correct).
--   * Function declared STABLE — pure read, deterministic per snapshot.
--   * Empty-set when no chars exist for the name (e.g. a freshly-created
--     account that has not yet rolled a character). The caller reads the
--     row count and falls back to ap_verify_account.
--   * Parameter widths verified against NCSoft schema:
--       @strAccountName NVARCHAR(14) → VARCHAR(14) (matches user_data.account_name
--                                                   added by 00008; the underlying
--                                                   PG column is TEXT, but the
--                                                   parameter is bounded for
--                                                   wire-compat with the launcher).
--   * RSA credential block size limit caps account_name at 17 chars at the
--     gateway layer (see ACE_5.8/CLAUDE.md key constraint #5). The 14 here
--     is a NCSoft historical leftover — pinned verbatim, the caller will
--     never push past it.
--
-- Bug-for-bug:
--   * No case-sensitivity guarantee. NCSoft SQL Server uses Korean_Wansung
--     collation which is case-insensitive by default; PostgreSQL TEXT is
--     case-sensitive. The launcher path normalises account_name to lower
--     before storage (handler enforces — out of scope for this SP).
--   * No upper-bound on result cardinality before LIMIT 1; for a name with
--     thousands of chars the planner will still scan the index — pinned
--     because adding ORDER BY would change semantics.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  (account_id resolution fallback)
--   scripts/lib/auth.lua                 (session migration warm-up)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvirtualauthaccountid(VARCHAR);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvirtualauthaccountid(_account_name VARCHAR(14))
RETURNS TABLE (
    account_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ud.account_id
          FROM user_data ud
         WHERE ud.account_name = _account_name
         LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvirtualauthaccountid(VARCHAR);
-- +goose StatementEnd
