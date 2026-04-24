-- scripts/events/on_auction_expire.lua
-- Phase S-18: called by jobq KindAuctionExpire worker (asynq) via the
-- LuaInvoker bridge. Runs inside a borrowed pooled VM, NOT in the context
-- of a CM_* packet — there is no ctx.gateway_seq_id and no ctx.entity_id.
--
-- Contract:
--   on_auction_expire(listing_id:int64)
--
-- The real settlement is performed by the aion_settleauction SP (S-18 patch
-- `procedures/patches/s18_aion_settleauction.sql`). The SP locks the listing
-- via FOR UPDATE SKIP LOCKED, dispatches payout mail(s), flips state=99, and
-- returns one row describing the outcome. We branch on outcome_code only to
-- produce structured logs — there is nothing else to do from Lua.
--
-- outcome_code ∈ { 0 = no_bids, 1 = sold, 2 = already_settled, 3 = missing }

function on_auction_expire(listing_id)
    if not db then
        log.warn("on_auction_expire: db unavailable, skipping settlement")
        return
    end

    -- Single SP call — the SP is transactional and idempotent, so we do NOT
    -- retry on nil rows (that case means the row was already processed by a
    -- twin worker; logging at info is sufficient).
    local rows, err = db.call("aion_settleauction", listing_id)
    if err then
        log.warn("on_auction_expire: SP err=" .. tostring(err))
        return
    end
    if not rows or #rows == 0 then
        log.info("on_auction_expire: listing_id=" .. tostring(listing_id)
            .. " no row returned")
        return
    end

    local row      = rows[1]
    local outcome  = tonumber(row.outcome_code or 0) or 0
    local winner   = tonumber(row.winner_cid   or 0) or 0
    local seller   = tonumber(row.seller_cid   or 0) or 0
    local bid      = tonumber(row.final_bid    or 0) or 0

    local base = "on_auction_expire: listing_id=" .. tostring(listing_id)
        .. " winner_cid=" .. tostring(winner)
        .. " seller_cid=" .. tostring(seller)
        .. " final_bid=" .. tostring(bid)

    if outcome == 0 then
        log.info(base .. " outcome=no_bids (returned to seller)")
    elseif outcome == 1 then
        log.info(base .. " outcome=sold")
    elseif outcome == 2 then
        log.info(base .. " outcome=already_settled (safe retry)")
    elseif outcome == 3 then
        log.warn(base .. " outcome=missing (stale expiry trigger)")
    else
        log.warn(base .. " outcome=unknown(" .. tostring(outcome) .. ")")
    end
end
