-- scripts/npcs/npc_798002.lua
-- Sanctum Gatekeeper — NPC template 798002.
--
-- Serves a teleport menu via the dialog framework. Destinations are stored
-- in _active_teleports keyed by the player's entity_id; the CM_TELEPORT
-- handler resolves the chosen option back to coordinates.
--
-- NCSoft data source for real destinations: client/Data/Strings/teleport_*.pak
-- For now we ship three example destinations in the Elyos starter zones.

local DESTINATIONS = {
    [1] = { name = "Sanctum Plaza",    world = 210010000, x = 1380, y = 1530, z = 570, price = 0 },
    [2] = { name = "Verteron Citadel", world = 210020000, x = 1690, y = 1390, z = 190, price = 500 },
    [3] = { name = "Eltnen Fortress",  world = 210030000, x = 1740, y = 2560, z = 320, price = 1500 },
}

dialog.register(798002, function(ctx, npc_eid, option_id)
    local gw = ctx.gateway_seq_id

    if option_id == 0 then
        -- Initial open: cache destinations and show the teleport menu.
        _active_teleports[ctx.entity_id] = DESTINATIONS

        local options = {}
        for id, dst in pairs(DESTINATIONS) do
            options[#options + 1] = {
                id   = id,
                text = dst.name .. " — " .. tostring(dst.price) .. " kinah",
            }
        end
        options[#options + 1] = { id = 0, text = "Cancel." }

        dialog.send_window(gw, npc_eid,
            "Gatekeeper",
            "Where would you like to travel, Daeva?",
            options)

    elseif DESTINATIONS[option_id] then
        -- The client may send CM_DIALOG_SELECT with the destination id.
        -- Forward it to the teleport handler path by synthesising a payload.
        -- In practice the 5.8 client sends CM_TELEPORT directly; this branch
        -- provides a fallback so the dialog alone is enough to teleport.
        local dst = DESTINATIONS[option_id]
        if dst.price and dst.price > 0 then
            if not player.spend_kinah(gw, dst.price) then
                chat.send_system(gw, "Not enough kinah.")
                return
            end
        end
        entity.set_position(ctx.entity_id, dst.x, dst.y, dst.z, 0)

        -- Emit SM_TELEPORT_LOC just like cm_teleport would.
        local buf = bytes.new()
        buf:write_int32(ctx.entity_id)
        buf:write_int32(dst.world or 0)
        buf:write_float32(dst.x)
        buf:write_float32(dst.y)
        buf:write_float32(dst.z)
        local pkt = buf:to_string()
        player.send_packet(gw, 0x70, pkt)

        _active_teleports[ctx.entity_id] = nil
        log.info("Gatekeeper: entity=" .. tostring(ctx.entity_id)
            .. " teleported to " .. dst.name)
    end
end)
