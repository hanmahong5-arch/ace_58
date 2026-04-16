-- scripts/handlers/cm_auction_cancel.lua
-- CM_AUCTION_CANCEL (0xCC): seller withdraws a listing (only allowed before
-- any bids have been placed).
--
-- Payload (LE):
--   int64 listing_id

register_handler(0xCC, function(ctx, payload)
    if not auction then
        log.warn("CM_AUCTION_CANCEL: auction lib not loaded")
        return
    end

    local listing_id = payload:read_int64()

    local ok, reason = auction.cancel(ctx.entity_id, listing_id)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Cancel failed: " .. tostring(reason))
        end
        log.info("CM_AUCTION_CANCEL: rejected entity=" .. tostring(ctx.entity_id)
            .. " listing_id=" .. tostring(listing_id)
            .. " reason=" .. tostring(reason))
        return
    end

    -- Confirm to the seller via SM_AUCTION_NOTIFY event=4 (cancelled).
    local buf = bytes.new()
    buf:write_int64(listing_id)
    buf:write_byte(4) -- event: cancelled
    buf:write_int64(0)
    player.send_packet(ctx.gateway_seq_id, 0xCE, buf:to_string())

    log.info("CM_AUCTION_CANCEL: ok entity=" .. tostring(ctx.entity_id)
        .. " listing_id=" .. tostring(listing_id))
end)
