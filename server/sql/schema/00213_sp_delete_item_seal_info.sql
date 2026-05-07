-- AionCore 5.8 — Sprint 1.1a batch 15 port: aion_DeleteItemSealInfo (item-seal DELETE).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteItemSealInfo.sql
-- Original (T-SQL):
--   DELETE user_item_sealed WHERE id = @item_id
--
-- Translation notes:
--   * Sister of 00211 SetItemSealInfo / 00212 GetItemSealInfo. Removes the
--     seal record by primary key (the user_item.id surrogate).
--   * NCSoft signature is `@item_id INT` — a bug NCSoft never fixed: the
--     user_item_sealed.id column is BIGINT (matches user_item.id BIGINT),
--     but the SP parameter declares INT. T-SQL silently widens INT → BIGINT
--     in the WHERE clause, so item_ids that fit in 32 bits round-trip fine
--     (which is all production traffic — id space hasn't grown past INT_MAX
--     in NCSoft's lifetime). The 4.8/5.8 client sends id as a 64-bit value,
--     so we accept BIGINT explicitly here — strictly safer than pinning the
--     bug verbatim, since callers may pass a true 64-bit id.
--   * Returns rows-affected (0 = no such id; 1 = deleted; >1 impossible by PK).
--   * No char_id guard — DELETE is by id alone. NCSoft trusts the caller to
--     have already authorised the delete. Pinned bug-for-bug.
--
-- Bug-for-bug:
--   * Permissive delete: any caller with the id can wipe the seal info,
--     even cross-char. T-SQL is identical. Application layer (handlers/
--     cm_item_seal*.lua) is responsible for ownership checks before invoking.
--
-- Used by:
--   scripts/handlers/cm_item_seal_unseal.lua  (after successful unseal)
--   scripts/handlers/cm_item_destroy.lua      (cleanup when sealed item is
--                                              destroyed)
--   scripts/lib/item_seal.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitemsealinfo(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitemsealinfo(_item_id BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    DELETE FROM user_item_sealed WHERE id = _item_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitemsealinfo(BIGINT);
-- +goose StatementEnd
