-- scripts/lib/shop.lua
-- Vendor shop operations.
--
-- A "shop" is an associative array mapping item_id -> price (kinah per unit).
-- Shop data lives inside the NPC dialog script (scripts/npcs/npc_XXXX.lua).
--
-- Usage from a dialog handler:
--   local SHOP = { [100000000] = 100, [100000001] = 500 }
--   shop.buy(ctx, SHOP, item_id, count)  -> ok, reason
--   shop.sell(ctx, item_id, count, unit_price) -> ok, reason

shop = {}

-- Sell-back ratio: vendors buy items at 25 % of the listed price.
local SELL_RATIO = 0.25

-- --------------------------------------------------------
-- shop.buy(ctx, shop_table, item_id, count) -> ok, reason
--   "not_in_shop" — item not listed in this shop
--   "bad_count"   — count <= 0
--   "no_kinah"    — balance < total cost
--   "add_failed"  — SP call to add item failed
-- On success: deducts kinah, calls player.add_item, returns true.
-- --------------------------------------------------------
shop.buy = function(ctx, shop_table, item_id, count)
    if not count or count <= 0 then
        return false, "bad_count"
    end
    local unit_price = shop_table and shop_table[item_id]
    if not unit_price then
        return false, "not_in_shop"
    end

    local total = unit_price * count
    if not player.spend_kinah(ctx.gateway_seq_id, total) then
        return false, "no_kinah"
    end

    -- player.add_item has no return value; treat missing DB as ok in dev.
    player.add_item(ctx.gateway_seq_id, item_id, count)

    log.info("shop.buy: entity=" .. tostring(ctx.entity_id)
        .. " item=" .. tostring(item_id) .. " x" .. tostring(count)
        .. " cost=" .. tostring(total))
    return true
end

-- --------------------------------------------------------
-- shop.sell(ctx, item_id, count, unit_price) -> ok, reason
--   "bad_count"    — count <= 0
--   "remove_failed" — inventory did not contain enough
-- On success: removes items, credits kinah (unit_price * count * SELL_RATIO).
-- --------------------------------------------------------
shop.sell = function(ctx, item_id, count, unit_price)
    if not count or count <= 0 then
        return false, "bad_count"
    end

    -- Remove items first — the SP returns false if the player lacked the stack.
    if not player.remove_item(ctx.gateway_seq_id, item_id, count) then
        return false, "remove_failed"
    end

    local payout = math.floor((unit_price or 0) * count * SELL_RATIO)
    if payout > 0 then
        player.add_kinah(ctx.gateway_seq_id, payout)
    end

    log.info("shop.sell: entity=" .. tostring(ctx.entity_id)
        .. " item=" .. tostring(item_id) .. " x" .. tostring(count)
        .. " payout=" .. tostring(payout))
    return true
end

-- --------------------------------------------------------
-- shop.open_window(gw, npc_eid, title, shop_table)
-- Convenience helper that sends SM_DIALOG_WINDOW with a synthetic listing.
-- Each item in shop_table becomes an option_id that the client can select
-- to trigger CM_BUY_ITEM.
-- --------------------------------------------------------
shop.open_window = function(gw, npc_eid, title, shop_table)
    if not dialog then return end
    local options = {}
    for item_id, price in pairs(shop_table or {}) do
        options[#options + 1] = {
            id   = item_id,
            text = "Item " .. tostring(item_id) .. " — " .. tostring(price) .. " kinah",
        }
    end
    dialog.send_window(gw, npc_eid, title or "Shop", "Select an item to purchase:", options)
end
