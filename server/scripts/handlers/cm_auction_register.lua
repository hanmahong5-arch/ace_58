-- scripts/handlers/cm_auction_register.lua
-- CM_AUCTION_REGISTER (0xCA): seller lists an item on the auction house.
--
-- Payload (LE):
--   int32 item_id
--   int32 count
--   int64 min_bid
--   int64 buy_now
--   int32 duration_hours

register_handler(0xCA, function(ctx, payload)
    if not auction then
        log.warn("CM_AUCTION_REGISTER: auction lib not loaded")
        return
    end
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local item_id  = payload:read_int32()
    local count    = payload:read_int32()
    local min_bid  = payload:read_int64()
    local buy_now  = payload:read_int64()
    local duration = payload:read_int32()

    local ok, result = auction.register(ctx.entity_id, item_id, count,
        min_bid, buy_now, duration)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Auction register failed: " .. tostring(result))
        end
        log.info("CM_AUCTION_REGISTER: rejected entity=" .. tostring(ctx.entity_id)
            .. " reason=" .. tostring(result))
        return
    end

    -- Success: result holds the listing_id. Notify the seller via
    -- SM_AUCTION_NOTIFY with event=0 (registered).
    local buf = bytes.new()
    buf:write_int64(result)
    buf:write_byte(0)              -- event: registered
    buf:write_int64(min_bid)
    player.send_packet(ctx.gateway_seq_id, 0xCE, buf:to_string())

    log.info("CM_AUCTION_REGISTER: ok entity=" .. tostring(ctx.entity_id)
        .. " listing_id=" .. tostring(result))
end)
