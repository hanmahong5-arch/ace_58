-- AionCore 5.8 — Sprint 1.1a batch 25 port: aion_deleteAuctionBetting
-- (housing-auction bidding cancel — DELETE one row by char_id).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_deleteAuctionBetting.sql
-- Original (T-SQL):
--   delete from user_betting where ownerid = @ownerid
--
-- Domain (`house_bidding`, batch 25 — sister to 00259, 00071):
--   Removes a character's active housing-auction bid. Called when:
--     * Player cancels their bid manually (UI button)
--     * Auction settles (winner OR loser path) — both bidders' rows
--       are cleared after the new owner is locked in
--     * Player logs out (depending on NCSoft policy — pinned at "no",
--       since the SP is only called from the explicit cancel/settle
--       paths in NCSoft scripts).
--
-- Schema:
--   `user_betting` PK = `ownerid` (see 00052 / 00259 / 00071). DELETE on
--   PK is atomic and 0-or-1 row.
--
-- Translation notes:
--   * Single-statement DELETE; no UPDLOCK in NCSoft (single-row PK delete
--     is atomic on both engines).
--   * Returns INTEGER row-count (a strict widening of NCSoft's VOID
--     contract — same convention as 00251 deletepvpenv, 00253). Lua
--     callers may ignore. 0 means "no bid existed"; 1 means "cancelled".
--
-- Bug-for-bug:
--   * No FK validation on ownerid — accepts any INTEGER; only the
--     PK match drives deletion. Pinned.
--   * Missing row → returns 0, no error. Pinned.
--   * The SP does NOT verify that the caller IS the owner; it deletes
--     by the supplied ownerid blindly. Authorisation is the caller's
--     job (Lua handler must compare session char_id == request char_id
--     before invoking). Pinned: NCSoft same gap.
--
-- Used by:
--   scripts/handlers/cm_house_bidding_cancel.lua   -- player cancel UI
--   scripts/lib/auction.lua                         -- settle helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteauctionbetting(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
-- _ownerid : char_id of the bidder whose row should be removed.
-- Returns INTEGER rows-affected (0 if no bid existed, 1 on cancel).
CREATE OR REPLACE FUNCTION aion_deleteauctionbetting(
    _ownerid INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected INTEGER;
BEGIN
    DELETE FROM user_betting WHERE ownerid = _ownerid;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteauctionbetting(INTEGER);
-- +goose StatementEnd
