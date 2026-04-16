-- scripts/lib/auction.lua
-- Phase S-16: Auction House state machine.
--
-- Responsibilities:
--   * Validate and register listings (from warehouse or inventory).
--   * Charge a non-refundable listing fee up front.
--   * Schedule a one-shot expiry task via jobq.enqueue (delay in seconds).
--   * Accept bids with atomic escrow (buyer's kinah held on the listing row).
--   * Let sellers cancel listings that have not yet received a bid.
--   * Search the listings table with optional filters (SP-side).
--
-- Contract:
--   auction.MAX_ACTIVE_PER_USER = 15
--   auction.LISTING_FEE_RATE    = 0.02
--   auction.MIN_DURATION_HOURS  = 6
--   auction.MAX_DURATION_HOURS  = 48
--
--   auction.register(seller_eid, item_id, count, min_bid, buy_now,
--                    duration_hours) -> ok, reason_or_listing_id
--     reasons: "bad_count" | "bad_bid" | "bad_duration" | "no_kinah"
--              | "too_many_listings" | "sp_failed"
--
--   auction.search(buyer_eid, item_id, min_price, max_price, page)
--     -> array of listing rows (possibly empty)
--
--   auction.bid(buyer_eid, listing_id, amount) -> ok, reason
--     reasons: "bad_amount" | "not_found" | "expired" | "own_listing"
--              | "bid_too_low" | "no_kinah" | "sp_failed"
--
--   auction.cancel(seller_eid, listing_id) -> ok, reason
--     reasons: "not_found" | "not_owner" | "has_bids" | "sp_failed"
--
-- Design notes:
--   - SP names (aion_InsertAuctionListing / aion_GetAuctionSearch /
--     aion_InsertAuctionBid / aion_CancelAuction / aion_CountActiveAuctions)
--     are placeholders; verify against the migration bundle.
--   - Expiry is asynq-scheduled (kind "aion58.auction.expire") and processed
--     by the Phase S-17 settlement worker. If Redis is unavailable the Lua
--     binding returns (false, "disabled") which auction.register treats as
--     "listing persisted but no automatic expiry" — ops can still run a
--     periodic SP sweep as a safety net.
--   - Seller fee is charged once at register time; auction.cancel does NOT
--     refund the fee to discourage spam listings.
--   - Bid escrow: new bid kinah is held on the listing row; when outbid the
--     previous bidder is refunded by the settlement worker. For MVP the
--     refund path is logged as a TODO — Phase S-17 wires aion_RefundBidder.

auction = {}

auction.MAX_ACTIVE_PER_USER = 15
auction.LISTING_FEE_RATE    = 0.02       -- 2 % of min_bid, rounded up to int
auction.MIN_DURATION_HOURS  = 6
auction.MAX_DURATION_HOURS  = 48

local function _char_id(eid)
    return math.floor(entity.get_stat(eid, "char_id") or 0)
end

local function _listing_fee(min_bid)
    local fee = math.ceil(min_bid * auction.LISTING_FEE_RATE)
    if fee < 1 then fee = 1 end
    return fee
end

-- --- auction.register ---------------------------------------------------

auction.register = function(seller_eid, item_id, count, min_bid, buy_now, duration_hours)
    item_id        = tonumber(item_id)        or 0
    count          = tonumber(count)          or 0
    min_bid        = tonumber(min_bid)        or 0
    buy_now        = tonumber(buy_now)        or 0
    duration_hours = tonumber(duration_hours) or 0

    if item_id <= 0 or count <= 0 then
        return false, "bad_count"
    end
    if min_bid <= 0 or (buy_now > 0 and buy_now < min_bid) then
        return false, "bad_bid"
    end
    if duration_hours < auction.MIN_DURATION_HOURS
       or duration_hours > auction.MAX_DURATION_HOURS then
        return false, "bad_duration"
    end

    local gw = entity.get_gateway_id(seller_eid)
    if not gw then return false, "no_kinah" end

    local cid = _char_id(seller_eid)
    if cid == 0 or not db then
        return false, "sp_failed"
    end

    -- Active-listing count check.
    local rows, cerr = db.call("aion_CountActiveAuctions", cid)
    if not cerr and rows and #rows > 0 then
        local active = tonumber(rows[1].count or rows[1].active or 0) or 0
        if active >= auction.MAX_ACTIVE_PER_USER then
            return false, "too_many_listings"
        end
    end

    -- Charge fee first so refund on SP failure is trivial.
    local fee = _listing_fee(min_bid)
    if not player.spend_kinah(gw, fee) then
        return false, "no_kinah"
    end

    local expires_at = os.time() + duration_hours * 3600
    local srows, serr = db.call("aion_InsertAuctionListing",
        cid, item_id, count, min_bid, buy_now, expires_at)
    if serr then
        player.add_kinah(gw, fee) -- rollback
        log.warn("auction.register: SP err=" .. tostring(serr))
        return false, "sp_failed"
    end

    local listing_id = 0
    if srows and #srows > 0 then
        listing_id = tonumber(srows[1].listing_id or srows[1].id or 0) or 0
    end

    -- Schedule asynq expiry (nil-safe via jobq binding; "disabled" is logged
    -- but does NOT roll back the listing — ops can sweep via SP).
    if jobq then
        local ok, reason = jobq.enqueue(
            "aion58.auction.expire",
            { listing_id = listing_id },
            duration_hours * 3600)
        if not ok and reason ~= "disabled" then
            log.warn("auction.register: expiry enqueue failed reason="
                .. tostring(reason))
        end
    end

    log.info("auction.register: seller=" .. tostring(cid)
        .. " item_id=" .. tostring(item_id)
        .. " listing_id=" .. tostring(listing_id)
        .. " expires_at=" .. tostring(expires_at))
    return true, listing_id
end

-- --- auction.search ------------------------------------------------------

auction.search = function(buyer_eid, item_id_filter, min_price, max_price, page)
    if not db then return {} end

    item_id_filter = tonumber(item_id_filter) or 0
    min_price      = tonumber(min_price)      or 0
    max_price      = tonumber(max_price)      or 0
    page           = tonumber(page)           or 0

    local rows, err = db.call("aion_GetAuctionSearch",
        item_id_filter, min_price, max_price, page)
    if err or not rows then
        if err then log.warn("auction.search: SP err=" .. tostring(err)) end
        return {}
    end
    return rows
end

-- --- auction.bid ---------------------------------------------------------

auction.bid = function(buyer_eid, listing_id, amount)
    listing_id = tonumber(listing_id) or 0
    amount     = tonumber(amount)     or 0

    if listing_id <= 0 or amount <= 0 then
        return false, "bad_amount"
    end

    local gw = entity.get_gateway_id(buyer_eid)
    if not gw then return false, "no_kinah" end

    local cid = _char_id(buyer_eid)
    if cid == 0 or not db then
        return false, "sp_failed"
    end

    -- Fetch the listing to validate ownership / expiry / min bid.
    local rows, ferr = db.call("aion_GetAuctionById", listing_id)
    if ferr or not rows or #rows == 0 then
        return false, "not_found"
    end
    local row = rows[1]

    local seller_cid = tonumber(row.seller_char_id or row.seller_cid or 0) or 0
    if seller_cid == cid then
        return false, "own_listing"
    end

    local expires_at = tonumber(row.expires_at or 0) or 0
    if expires_at > 0 and os.time() >= expires_at then
        return false, "expired"
    end

    local current_bid = tonumber(row.current_bid or 0) or 0
    local min_bid     = tonumber(row.min_bid     or 0) or 0
    local required    = current_bid > 0 and (current_bid + 1) or min_bid
    if amount < required then
        return false, "bid_too_low"
    end

    if not player.spend_kinah(gw, amount) then
        return false, "no_kinah"
    end

    local _, berr = db.call("aion_InsertAuctionBid", listing_id, cid, amount)
    if berr then
        player.add_kinah(gw, amount) -- rollback escrow
        log.warn("auction.bid: SP err=" .. tostring(berr))
        return false, "sp_failed"
    end

    log.info("auction.bid: buyer=" .. tostring(cid)
        .. " listing_id=" .. tostring(listing_id)
        .. " amount=" .. tostring(amount))
    return true, nil
end

-- --- auction.cancel ------------------------------------------------------

auction.cancel = function(seller_eid, listing_id)
    listing_id = tonumber(listing_id) or 0
    if listing_id <= 0 then
        return false, "not_found"
    end

    local cid = _char_id(seller_eid)
    if cid == 0 or not db then
        return false, "sp_failed"
    end

    local rows, ferr = db.call("aion_GetAuctionById", listing_id)
    if ferr or not rows or #rows == 0 then
        return false, "not_found"
    end
    local row = rows[1]

    local seller_cid = tonumber(row.seller_char_id or row.seller_cid or 0) or 0
    if seller_cid ~= cid then
        return false, "not_owner"
    end
    local current_bid = tonumber(row.current_bid or 0) or 0
    if current_bid > 0 then
        return false, "has_bids"
    end

    local _, cerr = db.call("aion_CancelAuction", listing_id, cid)
    if cerr then
        log.warn("auction.cancel: SP err=" .. tostring(cerr))
        return false, "sp_failed"
    end

    log.info("auction.cancel: seller=" .. tostring(cid)
        .. " listing_id=" .. tostring(listing_id))
    return true, nil
end
