-- scripts/events/on_auction_expire.lua
-- Phase S-17: called by jobq KindAuctionExpire worker (asynq) via the
-- LuaInvoker bridge. Runs inside a borrowed pooled VM, NOT in the context
-- of a CM_* packet — there is no ctx.gateway_seq_id and no ctx.entity_id.
--
-- Contract:
--   on_auction_expire(listing_id:int64)
--
-- The canonical settlement path is:
--   1. aion_SettleAuction(listing_id)                -- returns winner_cid,
--      seller_cid, item_id, item_count, final_bid, outcome_code
--   2. If outcome_code == 1 (sold):
--        enqueue mail to winner with attached item + count (jobq.enqueue
--        kind "aion58.mail.deliver") OR direct SP aion_InsertMailUser
--        credit seller kinah via aion_AddKinahUser
--   3. If outcome_code == 0 (expired unsold):
--        enqueue return-mail to seller with the original item
--   4. Log + return
--
-- Phase S-17 scope leaves outcome handling as a structured log. The SP
-- names above are placeholders; production wiring lands in S-18 alongside
-- the real mail worker implementation.

function on_auction_expire(listing_id)
    log.info("on_auction_expire: listing_id=" .. tostring(listing_id))

    if not db then
        log.warn("on_auction_expire: db unavailable, skipping settlement")
        return
    end

    local rows, err = db.call("aion_SettleAuction", listing_id)
    if err then
        log.warn("on_auction_expire: SP err=" .. tostring(err))
        return
    end
    if not rows or #rows == 0 then
        log.info("on_auction_expire: no row (already settled)")
        return
    end

    local row = rows[1]
    log.info("on_auction_expire: settled"
        .. " listing_id=" .. tostring(listing_id)
        .. " winner_cid=" .. tostring(row.winner_cid or 0)
        .. " seller_cid=" .. tostring(row.seller_cid or 0)
        .. " final_bid=" .. tostring(row.final_bid or 0)
        .. " outcome=" .. tostring(row.outcome_code or 0))

    -- TODO S-18: dispatch mail to winner/seller via jobq.enqueue
    -- kind "aion58.mail.deliver" with the appropriate attachments.
end
