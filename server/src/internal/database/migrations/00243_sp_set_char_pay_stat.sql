-- AionCore 5.8 — Sprint 1.1a batch 21 port: aion_SetCharPayStat
-- (single-column UPDATE — pay_stat billing flag on user_data).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharPayStat.sql
-- Original (T-SQL):
--   UPDATE user_data SET pay_stat = @nPayStat WHERE char_id = @nCharId
--
-- Translation notes:
--   * pay_stat is a per-char billing-state flag. NCSoft uses it as a
--     bitfield-ish enum tracked alongside the account-level subscription
--     state, e.g. P-server / G-server era flags, F2P region overlay.
--     The wider 5.8 (post-F2P) build sets it during periodic payment
--     reconciliation (login_d / billing job). Pinned: server treats it
--     as opaque; the rendering / enforcement of pay_stat lives in the
--     login-server policy table, NOT in user_data SPs.
--   * Domain mate of 00239-00242 (4x growth tiers): they all UPDATE one
--     SMALLINT column on user_data with no guard. NCSoft pattern: the
--     billing job calls each one in turn during reconciliation. Pinned.
--   * Silent no-op on missing char_id. Pinned.
--   * @nPayStat is TINYINT (0-255) → SMALLINT in PG. PG column added in
--     00032 round-3 (SMALLINT NOT NULL DEFAULT 0).
--   * VOLATILE. RETURNS VOID.
--
-- Bug-for-bug:
--   * NO range CHECK on pay_stat values; the live billing pipeline ships
--     a 0..15-ish enum but the SP accepts any byte. Pinned.
--   * NO delete_date / banned guard — billing reconciliation must hit
--     even chars in the soft-delete window so refunds settle correctly.
--     Pinned: NCSoft intentionally omits the guard here.
--   * Last-writer-wins on concurrent calls; the billing job is single-
--     writer in practice.
--   * NO event log emitted by the SP itself — the audit trail comes from
--     the upstream billing reconciliation job's own logs (logd → ClickHouse
--     in our stack).
--
-- Used by:
--   scripts/handlers/cm_billing_reconcile.lua   -- internal billing tick
--   scripts/lib/shop.lua                        -- pay-state hook
--   (also: external login_d periodic job — out of game-server scope)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharpaystat(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _char_id  : owning user_data.char_id
-- _pay_stat : new billing flag (TINYINT 0-255 in T-SQL → SMALLINT in PG)
CREATE OR REPLACE FUNCTION aion_setcharpaystat(
    _char_id  INTEGER,
    _pay_stat SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET pay_stat = _pay_stat
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharpaystat(INTEGER, SMALLINT);
-- +goose StatementEnd
