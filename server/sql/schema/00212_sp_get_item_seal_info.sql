-- AionCore 5.8 — Sprint 1.1a batch 15 port: aion_GetItemSealInfo (item-seal SELECT).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetItemSealInfo.sql
-- Original (T-SQL):
--   SELECT id, sealState, sealExpiredTime
--   FROM user_item_sealed WITH(INDEX(IX_user_item_sealed_char_id), NOLOCK)
--   WHERE char_id = @char_id
--
-- Translation notes:
--   * Sister of 00211 SetItemSealInfo. Reads all sealed items belonging to a
--     character. user_item_sealed table + idx_user_item_sealed_char_id are
--     created by 00211; this migration only adds the function.
--   * `WITH(INDEX(IX_user_item_sealed_char_id))` is a SQL Server index hint —
--     PG planner picks the index automatically given the existing
--     idx_user_item_sealed_char_id; the hint is ignored. STABLE marker lets
--     the planner inline the call into outer joins when callers wrap it.
--   * `WITH(NOLOCK)` is dirty-read; PG's MVCC snapshot already provides the
--     non-blocking read property the original was after, without the
--     dirty-read footgun. Dropped (matches 00148 GetFamiliarList precedent).
--   * Return shape preserved verbatim — (id BIGINT, sealState INT,
--     sealExpiredTime INT) — so the gateway-side reader does not need to
--     rebind columns.
--   * Empty result for chars without sealed items is fine — RETURN QUERY
--     of an empty SELECT yields zero rows.
--
-- Bug-for-bug:
--   * No filter on sealExpiredTime — expired seals still appear in the result.
--     NCSoft expects the application layer (combat/UI) to interpret expiry.
--     Not adding a server-side filter preserves admin observability of
--     expired-but-not-yet-purged seal rows.
--
-- Used by:
--   scripts/handlers/cm_item_seal_list.lua  (post-login seal snapshot)
--   scripts/lib/item_seal.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemsealinfo(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitemsealinfo(_char_id INTEGER)
RETURNS TABLE (
    id                BIGINT,
    "sealState"       INTEGER,
    "sealExpiredTime" INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT s.id, s."sealState", s."sealExpiredTime"
          FROM user_item_sealed s
         WHERE s.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitemsealinfo(INTEGER);
-- +goose StatementEnd
