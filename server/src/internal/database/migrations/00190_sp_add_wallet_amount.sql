-- AionCore 5.8 — Sprint 1.1a batch 11 port: aion_addwalletamount.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_addwalletamount.sql
-- Original (T-SQL):
--   update user_wallet set amount=amount+@add where ID = @id
--
-- Translation notes:
--   * Pure UPDATE on the wallet row keyed by surrogate `id` (NOT char_id /
--     name_id). The caller is expected to have resolved the row id via
--     00191 GetWalletQina earlier in the same flow — this is NCSoft's
--     pattern for keeping the hot path (currency mutation) on a single-row
--     PK lookup, regardless of how many wallet namespaces a character may
--     accumulate.
--   * `@add` is BIGINT — both adds (purchases earn) and subtracts (purchases
--     spend) are expressed as `amount = amount + delta`. PG `column = column
--     + delta` is atomic at row level under READ COMMITTED, so two
--     concurrent adds on the same id serialise via row lock and BOTH
--     deltas are observable. Crucial for currency integrity.
--   * NO check that `amount + delta >= 0`. T-SQL doesn't gate this either;
--     overflow protection (e.g. preventing negative balance, cap at int64)
--     is the caller's responsibility. Lua wallet helpers gate it before
--     dispatching the SP. Bug-for-bug PG mirror keeps the SP a dumb
--     arithmetic primitive.
--   * Returns rows-affected so the caller can detect "row id unknown" (0)
--     vs "delta committed" (1). 5.8 client surfaces 0 as "wallet vanished"
--     toast (extremely rare).
--   * Table user_wallet created in 00189 (PutWallet); migration is
--     order-dependent on 00189 having run first.
--
-- Used by:
--   scripts/lib/wallet.lua            -- credit/debit primitive
--   scripts/handlers/cm_buy_qna_*.lua -- cash-shop purchase chain

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addwalletamount(BIGINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addwalletamount(
    _id  BIGINT,
    _add BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    UPDATE user_wallet
       SET amount = amount + _add
     WHERE id = _id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addwalletamount(BIGINT, BIGINT);
-- +goose StatementEnd
