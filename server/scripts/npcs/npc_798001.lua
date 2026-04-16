-- scripts/npcs/npc_798001.lua
-- General Goods Merchant (Sanctum) — NPC template 798001.
--
-- Demonstrates the dialog + shop integration pattern:
--   1. On dialog.open, the handler caches a per-player SHOP table and sends
--      SM_DIALOG_WINDOW with two options (BUY or EXIT).
--   2. If the player picks BUY, the handler opens the vendor listing as a
--      secondary dialog whose option_ids are item_ids.
--   3. The CM_BUY_ITEM handler reads the cached shop from _active_shops
--      and completes the transaction.
--
-- Template ID 798001 is illustrative — real NPC templates live in
-- client/Data/Npcs/*.pak and must be matched against world spawn data.

local SHOP = {
    [100000001] = 50,     -- Minor Health Potion
    [100000002] = 50,     -- Minor Mana Potion
    [100000100] = 1500,   -- Basic Scroll of Return
}

local OPT_EXIT = 0
local OPT_BUY  = 1

dialog.register(798001, function(ctx, npc_eid, option_id)
    local gw = ctx.gateway_seq_id

    if option_id == 0 then
        -- Initial open: greet + offer BUY/EXIT.
        dialog.send_window(gw, npc_eid,
            "General Goods",
            "Hail, Daeva. I deal in potions and basic scrolls. What do you need?",
            {
                { id = OPT_BUY,  text = "Show me your wares." },
                { id = OPT_EXIT, text = "Farewell." },
            })

    elseif option_id == OPT_BUY then
        -- Activate shop session and send the item list.
        _active_shops[ctx.entity_id] = SHOP
        shop.open_window(gw, npc_eid, "General Goods — Buy", SHOP)

    elseif SHOP[option_id] then
        -- option_id IS a listed item_id — client clicked on one of the rows.
        -- Server-side auto-buy 1 unit; client may also send explicit CM_BUY_ITEM.
        local ok, reason = shop.buy(ctx, SHOP, option_id, 1)
        if not ok then
            chat.send_system(gw, "Cannot buy: " .. tostring(reason))
        end

    elseif option_id == OPT_EXIT then
        _active_shops[ctx.entity_id] = nil
    end
end)
