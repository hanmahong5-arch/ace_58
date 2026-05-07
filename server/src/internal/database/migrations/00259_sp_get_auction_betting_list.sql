-- AionCore 5.8 — Sprint 1.1a batch 25 port: aion_GetAuctionBettingList
-- (housing-auction bidding registry SELECT — full table dump).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetAuctionBettingList.sql
-- Original (T-SQL):
--   SELECT ownerid, auctionid, qina FROM user_betting
--
-- Domain (`house_bidding`, batch 25):
--   `user_betting` is the at-most-one-bet-per-character ledger that backs
--   the housing auction bidding system (NCSoft fuses "auction" UI on top
--   of player housing — house listings are surfaced as auction goods).
--   Sister SPs already ported:
--     * 00071 aion_setAuctionBetting  (UPSERT)
--   Sister SPs in this batch (00259-00263):
--     * 00259 aion_GetAuctionBettingList  (this file — full SELECT)
--     * 00260 aion_deleteAuctionBetting   (cancel bid)
--     * 00261 aion_PutHouseField          (decoration row INSERT)
--     * 00262 aion_SetHouseField          (decoration row UPDATE)
--     * 00263 aion_RemoveHouseField       (decoration row DELETE)
--
-- Schema:
--   `user_betting` is created by 00052 pve_scaffold_round4 and is also
--   populated by 00071 setAuctionBetting (UPSERT). Three columns:
--     ownerid    INTEGER PRIMARY KEY
--     auctionid  BIGINT  NOT NULL          -- references user_auction.id
--     qina       BIGINT  NOT NULL DEFAULT 0
--   Column casing in PG is unquoted lowercase — NCSoft's mixed-case
--   column names are case-folded by SQL Server but PG would respect
--   case if quoted. The 00052 DDL uses lowercase, so callers/tests
--   must use lowercase too.
--
-- Translation notes:
--   * No parameters — full table SELECT. NCSoft's intent is admin/GM
--     reporting (or seldom-called UI refresh). Returns 0 to N rows.
--   * RETURNS TABLE (...) — three-column projection that mirrors the
--     T-SQL SELECT verbatim. STABLE marker — read-only.
--   * No NOLOCK hint in T-SQL source. PG MVCC snapshot is sufficient.
--   * Column projection ordering is preserved verbatim from NCSoft for
--     wire-protocol stability.
--
-- Bug-for-bug:
--   * No filtering at all — returns the entire `user_betting` table even
--     for characters whose `auctionid` references a long-since-resolved
--     auction (state>=2 in user_auction). NCSoft pinned: it is the
--     caller's responsibility to JOIN with user_auction if it wants
--     active-only bids. We do NOT widen the predicate.
--   * Stale rows: 00260 deleteAuctionBetting is called on bid cancel and
--     on auction-settle-completed. If either path is missed by Lua, this
--     SP surfaces orphans. Pinned (NCSoft same gap).
--   * No paging; on a fully populated server with N concurrent bids
--     this returns N rows in one call. NCSoft never had problems at
--     5.8-era scale (~thousands of concurrent housing auction bidders);
--     pinned.
--
-- Used by:
--   scripts/handlers/cm_house_bidding_list.lua   -- bidding overview
--   scripts/lib/auction.lua                       -- shared bidding helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionbettinglist();
-- +goose StatementEnd

-- +goose StatementBegin
-- No parameters. Returns the entire user_betting table — three columns,
-- order preserved from NCSoft (ownerid, auctionid, qina).
CREATE OR REPLACE FUNCTION aion_getauctionbettinglist()
RETURNS TABLE (
    ownerid   INTEGER,
    auctionid BIGINT,
    qina      BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT b.ownerid, b.auctionid, b.qina
          FROM user_betting b;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionbettinglist();
-- +goose StatementEnd
