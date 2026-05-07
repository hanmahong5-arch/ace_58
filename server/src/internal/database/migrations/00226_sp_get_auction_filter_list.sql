-- AionCore 5.8 — Sprint 1.1a batch 18 port: aion_GetAuctionFilterList
-- (housing auction filter SELECT by type).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetAuctionFilterList.sql
-- Original (T-SQL):
--   SELECT goodsid from user_auctionfilter where type = @type
--
-- Translation notes:
--   * Returns the goods_id list of all entries inside a single type bucket.
--     The 5.8 client calls this on auction-list refresh to know which
--     buildings to suppress in the type-N view.
--   * Parameter widths verified against NCSoft schema:
--       @type   INT  → INTEGER (auction class bucket)
--   * Single-column projection (goodsID only) — char_id/owner is not part
--     of this table because the filter is server-wide (see 00224 notes).
--   * No NOLOCK hint in T-SQL source. PG MVCC snapshot is sufficient.
--   * STABLE marker — read-only.
--
-- Bug-for-bug:
--   * The Add path (00224) blocks duplicates by goodsID alone, but Get
--     filters by type alone — combined behaviour: a goods_id entered
--     under type 1 will NOT appear in the Get(type=2) result, even though
--     Add(type=2,...) would skip inserting it. The intersection of these
--     two SPs makes type-2 callers think nothing is filtered while Add
--     silently rejects. NCSoft pinned both; do NOT "fix" Get to widen.
--
-- Used by:
--   scripts/handlers/cm_house_auction_filter_list.lua  (UI refresh)
--   scripts/lib/auction.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionfilterlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getauctionfilterlist(_type INTEGER)
RETURNS TABLE (goodsid INTEGER)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    -- Single-column projection. NCSoft selects goodsid (lowercase casing
    -- in the original SP body — column lives as goodsID in DDL but T-SQL
    -- is case-insensitive). PG would be case-sensitive without quoting; we
    -- alias to the lowercase return name explicitly.
    RETURN QUERY
        SELECT f.goodsID
          FROM user_auctionfilter f
         WHERE f.type = _type;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionfilterlist(INTEGER);
-- +goose StatementEnd
