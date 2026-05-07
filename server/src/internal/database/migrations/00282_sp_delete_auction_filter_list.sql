-- AionCore 5.8 — batch 28 / 2 of 5 ("Delete-族杂项"):
--   aion_DeleteAuctionFilterList — housing-auction filter REMOVE by
--   (type, goodsID).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteAuctionFilterList.sql
-- Original (T-SQL):
--   CREATE PROCEDURE [dbo].[aion_DeleteAuctionFilterList]
--       @type int,
--       @goods int
--   AS
--   BEGIN
--       SET NOCOUNT ON;
--       delete from user_auctionfilter where type = @type and goodsID = @goods
--   END
--
-- Lineage note (batch 28 idempotent re-affirmation):
--   * First ported in 00225 (Sprint 1.1a batch 18) — same body, same args.
--     This batch-28 migration RE-states via CREATE OR REPLACE for cohort
--     audit grouping. Underlying table `user_auctionfilter` is declared in
--     00052; this migration does NOT redefine it.
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
--     Delete scopes by (type, goodsID). A row inserted under type=1 can
--     ONLY be deleted with type=1; calling delete with the wrong type
--     leaves the filter in place silently (0 rows). NCSoft pinned both
--     behaviours; we mirror exactly. Do NOT "harmonise" the scopes.
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
-- _type   : filter slot type (NCSoft @type)
-- _goods  : housing goodsID — exact tuple key with _type
-- Returns INTEGER rows-affected (0 if no matching row, 1 on remove).
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
-- Down is a no-op (see 00281 Down rationale — preserve 00225's body).
SELECT 1;
-- +goose StatementEnd
