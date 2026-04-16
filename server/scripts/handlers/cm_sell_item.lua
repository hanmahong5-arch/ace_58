-- scripts/handlers/cm_sell_item.lua
-- CM_SELL_ITEM (0x6D): player sells inventory items back to a vendor.
--
-- Payload (LE, unverified):
--   int32  npc_entity_id
--   int32  item_id
--   int32  count
--   int32  unit_price   -- client-supplied base price; server applies SELL_RATIO

register_handler(0x6D, function(ctx, payload)
    local _npc_eid   = payload:read_int32()
    local item_id    = payload:read_int32()
    local count      = payload:read_int32()
    local unit_price = payload:read_int32()

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    -- Refuse if the player is not currently in a shop session (anti-exploit).
    if not _active_shops[ctx.entity_id] then
        chat.send_system(ctx.gateway_seq_id, "No active shop.")
        return
    end

    -- Clamp unit_price against the shop listing if present; otherwise trust it
    -- only as a lower bound (vendors have no reason to overpay).
    local listed = _active_shops[ctx.entity_id][item_id]
    if listed and unit_price > listed then
        unit_price = listed
    end

    local ok, reason = shop.sell(ctx, item_id, count, unit_price)
    if not ok then
        chat.send_system(ctx.gateway_seq_id, "Sell failed: " .. tostring(reason))
    end
end)
