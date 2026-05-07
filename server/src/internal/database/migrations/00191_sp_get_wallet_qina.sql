-- AionCore 5.8 — Sprint 1.1a batch 11 port: aion_getwalletqina.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_getwalletqina.sql
-- Original (T-SQL):
--   select ID, amount from user_wallet where char_id=@char_id and name_id=18240001
--
-- Translation notes:
--   * Read-only lookup of the Quna row for a given character. Used as the
--     hand-off step before 00190 AddWalletAmount: caller resolves (id,
--     amount), shows current balance to the client, then dispatches a
--     delta with the resolved id.
--   * `18240001` is the same Quna namespace constant baked into 00189
--     PutWallet — the two SPs MUST stay in lockstep. If a future content
--     change introduces a new currency namespace, both SPs need to gain a
--     name_id parameter (preferred) or get cloned per-currency (NCSoft
--     style). For 5.8 we mirror the hard-code.
--   * Returns 0 rows for an unknown char_id — the Lua helper interprets
--     missing as "wallet not yet seeded" and calls 00189 to repair. Both
--     paths are idempotent at the application layer.
--   * Multiple Quna rows for one char_id are POSSIBLE under T-SQL because
--     PutWallet has no UNIQUE constraint (see 00189 notes). PG mirrors
--     that: the SELECT can theoretically return >1 row. Lua wallet helper
--     consumes the first row and logs a warning if duplicates appear.
--   * No mutation, but explicit IMMUTABLE/STABLE marker is wrong here
--     because user_wallet IS mutable across calls. Function is left
--     VOLATILE (default) so PG won't cache.
--
-- Used by:
--   scripts/lib/wallet.lua            -- balance lookup primitive
--   scripts/handlers/cm_dialog_select.lua  -- shop UI populates balance

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwalletqina(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getwalletqina(
    _char_id INTEGER
) RETURNS TABLE (
    id     BIGINT,
    amount BIGINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
        SELECT w.id, w.amount
          FROM user_wallet w
         WHERE w.char_id = _char_id
           AND w.name_id = 18240001;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getwalletqina(INTEGER);
-- +goose StatementEnd
