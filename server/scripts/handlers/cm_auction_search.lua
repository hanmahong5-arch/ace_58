-- scripts/handlers/cm_auction_search.lua
-- CM_AUCTION_SEARCH (0xC9): client queries the auction listings.
--
-- Payload (LE):
--   int32 item_id_filter    -- 0 = any
--   int64 min_price
--   int64 max_price
--   int32 page              -- 0-based
--
-- Response SM_AUCTION_SEARCH_RESULT (0xCD):
--   int32 count
--   per row:
--     int64 listing_id, int32 item_id, int32 item_count,
--     int64 min_bid, int64 current_bid, int64 buy_now,
--     int64 expires_at_unix, utf16_null seller_name

register_handler(0xC9, function(ctx, payload)
    if not auction then
        log.warn("CM_AUCTION_SEARCH: auction lib not loaded")
        return
    end

    local item_filter = payload:read_int32()
    local min_price   = payload:read_int64()
    local max_price   = payload:read_int64()
    local page        = payload:read_int32()

    local rows = auction.search(ctx.entity_id, item_filter, min_price, max_price, page)
    local count = (rows and #rows) or 0

    local buf = bytes.new()
    buf:write_int32(count)
    for _, row in ipairs(rows or {}) do
        buf:write_int64(tonumber(row.listing_id  or row.id          or 0) or 0)
        buf:write_int32(tonumber(row.item_id     or 0) or 0)
        buf:write_int32(tonumber(row.item_count  or row.count       or 1) or 1)
        buf:write_int64(tonumber(row.min_bid     or 0) or 0)
        buf:write_int64(tonumber(row.current_bid or 0) or 0)
        buf:write_int64(tonumber(row.buy_now     or 0) or 0)
        buf:write_int64(tonumber(row.expires_at  or 0) or 0)
        buf:write_string_utf16(tostring(row.seller_name or row.seller or "?"))
    end

    player.send_packet(ctx.gateway_seq_id, 0xCD, buf:to_string())
    log.info("CM_AUCTION_SEARCH: entity=" .. tostring(ctx.entity_id)
        .. " count=" .. tostring(count))
end)
