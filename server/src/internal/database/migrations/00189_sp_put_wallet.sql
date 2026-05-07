-- AionCore 5.8 — Sprint 1.1a batch 11 port: aion_putwallet.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_putwallet.sql
-- Original (T-SQL):
--   insert into user_wallet (char_id, name_id, amount) values (@char_id, 18240001, 0)
--
-- Translation notes:
--   * `user_wallet` is the per-character soft-currency ledger. NCSoft uses it
--     for Quna (the cash-shop in-game currency, name_id=18240001) plus a few
--     other tokenized resources keyed by name_id. This SP seeds the **Quna
--     row** for a freshly-created character — called once during character
--     creation. The hard-coded `18240001` is the Quna namespace id (verified
--     from NCSoft strings dump, 5.8 client item table).
--   * NO uniqueness constraint in T-SQL — schema mirrors that. A character
--     could theoretically end up with two Quna rows if creation is replayed.
--     Real-world this is gated by the character-creation transaction, but
--     PG must not silently swallow that semantic. Bug-for-bug.
--   * Table created here as the first consumer in the SP catalogue; 00190
--     (AddWalletAmount) and 00191 (GetWalletQina) read/mutate the same
--     shape. Surrogate `id BIGSERIAL PRIMARY KEY` is added so the GET path
--     can return the row's stable id (matches T-SQL `select ID,amount`).
--   * Returns rows-affected (always 1 for a successful insert) so the
--     caller can sanity-check the round-trip. T-SQL VOID return is upgraded
--     to INTEGER for parity with the rest of the batch.
--
-- Used by:
--   scripts/handlers/cm_create_character.lua  -- on new character creation
--   scripts/lib/wallet.lua                    -- helper layer

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- user_wallet — per-character per-currency soft-currency ledger.
-- (id is a surrogate so the GET path can return the row's stable handle;
-- T-SQL uses an IDENTITY column with the same role.)
-- ====================================================================
CREATE TABLE IF NOT EXISTS user_wallet (
    id      BIGSERIAL PRIMARY KEY,
    char_id INTEGER  NOT NULL,
    name_id INTEGER  NOT NULL,
    amount  BIGINT   NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_wallet_char_name ON user_wallet(char_id, name_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putwallet(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putwallet(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- 18240001 = Quna namespace id (NCSoft hardcoded constant).
    INSERT INTO user_wallet (char_id, name_id, amount)
    VALUES (_char_id, 18240001, 0);
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putwallet(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_wallet_char_name;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_wallet;
-- +goose StatementEnd
