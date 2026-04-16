-- scripts/handlers/cm_auction_bid.lua
-- CM_AUCTION_BID (0xCB): buyer places a bid on an existing listing.
--
-- Payload (LE):
--   int64 listing_id
--   int64 bid_amount

register_handler(0xCB, function(ctx, payload)
    if not auction then
        log.warn("CM_AUCTION_BID: auction lib not loaded")
        return
    end
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local listing_id = payload:read_int64()
    local amount     = payload:read_int64()

    local ok, reason = auction.bid(ctx.entity_id, listing_id, amount)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Bid rejected: " .. tostring(reason))
        end
        log.info("CM_AUCTION_BID: rejected entity=" .. tostring(ctx.entity_id)
            .. " listing_id=" .. tostring(listing_id)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_AUCTION_BID: ok entity=" .. tostring(ctx.entity_id)
        .. " listing_id=" .. tostring(listing_id)
        .. " amount=" .. tostring(amount))
end)
