-- scripts/handlers/cm_buy_item.lua
-- CM_BUY_ITEM (0x6C): player confirms a purchase from an open vendor window.
--
-- Payload (LE, unverified):
--   int32  npc_entity_id
--   int32  item_id
--   int32  count
--
-- The NPC dialog handler owns the shop table; this handler calls
-- dialog.select() with option_id == item_id, then shop.buy() inside the
-- handler consults the shop table for the unit price.
--
-- To preserve a clean separation we also cache the active shop table per
-- player in _active_shops; buy/sell resolve the price from that cache.

_active_shops = _active_shops or {}  -- ctx.entity_id -> shop_table

register_handler(0x6C, function(ctx, payload)
    local npc_eid = payload:read_int32()
    local item_id = payload:read_int32()
    local count   = payload:read_int32()

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local shop_table = _active_shops[ctx.entity_id]
    if not shop_table then
        chat.send_system(ctx.gateway_seq_id, "No active shop.")
        return
    end

    local ok, reason = shop.buy(ctx, shop_table, item_id, count)
    if not ok then
        chat.send_system(ctx.gateway_seq_id, "Purchase failed: " .. tostring(reason))
    end
end)
