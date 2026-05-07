-- AionCore 5.8 — Sprint 1.1a batch 18 port: aion_DeleteAuctionFilterList
-- (housing auction filter REMOVE by (type, goodsID)).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAuctionFilterList.sql
-- Original (T-SQL):
--   delete from user_auctionfilter where type = @type and goodsID = @goods
--
-- Translation notes:
--   * Pure DELETE on user_auctionfilter scoped by (type, goodsID).
--     The 5.8 client emits this when the player un-ticks "hide" for a
--     specific (type, building) pair in the housing auction UI.
--   * Parameter widths verified against NCSoft schema:
--       @type    INT   → INTEGER
--       @goods   INT   → INTEGER
--   * Returns rows-affected — 0 means there was no matching filter row
--     (idle un-filter), 1 means a row was removed. NCSoft @@ROWCOUNT pin.
--
-- Bug-for-bug:
--   * Asymmetric with the Add path (00224): Add guards on goodsID alone,
--     Delete scopes by (type, goodsID). This means a row inserted under
--     type=1 can ONLY be deleted with type=1 — calling delete with the
--     wrong type leaves the filter in place silently (0 rows). NCSoft
--     pinned both behaviours; we mirror exactly. Do NOT "harmonise" the
--     scopes.
--   * No char_id / owner column — same shared-list semantics as Add.
--   * No FK on goodsID; orphan filter rows can be deleted regardless.
--
-- Used by:
--   scripts/handlers/cm_house_auction_filter_remove.lua  (player un-hides)
--   scripts/lib/auction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteauctionfilterlist(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteauctionfilterlist(
    _type   INTEGER,
    _goods  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure DELETE scoped by (type, goodsID). 0 rows == row never existed
    -- under that exact (type, goodsID). Bug-for-bug asymmetric vs 00224.
    DELETE FROM user_auctionfilter
     WHERE type    = _type
       AND goodsID = _goods;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteauctionfilterlist(INTEGER, INTEGER);
-- +goose StatementEnd
