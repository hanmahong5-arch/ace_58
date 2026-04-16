-- scripts/npcs/npc_798004.lua
-- Warehouse Keeper (Sanctum) — NPC template 798004.
--
-- Dialog flow:
--   1. On open the keeper offers OPEN (begin a warehouse session) or EXIT.
--   2. OPEN calls warehouse.open_session(player, npc) so subsequent
--      CM_WAREHOUSE_* handlers can verify the session + range.
--   3. The handler sends SM_WAREHOUSE_LIST(0xC8) as the initial response so
--      the client can render the storage UI immediately. The client then
--      drives CM_WAREHOUSE_DEPOSIT / WITHDRAW for individual moves.
--   4. EXIT clears the session.

local OPT_EXIT = 0
local OPT_OPEN = 1

dialog.register(798004, function(ctx, npc_eid, option_id)
    local gw = ctx.gateway_seq_id

    if option_id == 0 then
        dialog.send_window(gw, npc_eid,
            "Warehouse Keeper",
            "Welcome, Daeva. I guard your stored belongings for a small fee.",
            {
                { id = OPT_OPEN, text = "Access my warehouse." },
                { id = OPT_EXIT, text = "Farewell." },
            })

    elseif option_id == OPT_OPEN then
        warehouse.open_session(ctx.entity_id, npc_eid)

        -- Push the current contents so the client UI has something to render.
        local rows = warehouse.list(ctx.entity_id)
        local buf = bytes.new()
        buf:write_int32(#rows)
        for _, row in ipairs(rows) do
            buf:write_int32(tonumber(row.item_id    or 0) or 0)
            buf:write_int32(tonumber(row.item_count or row.count or 1) or 1)
            buf:write_int32(tonumber(row.slot       or 0) or 0)
        end
        player.send_packet(gw, 0xC8, buf:to_string())

        log.info("npc_798004: warehouse session opened for entity="
            .. tostring(ctx.entity_id))

    elseif option_id == OPT_EXIT then
        warehouse.close_session(ctx.entity_id)
    end
end)
