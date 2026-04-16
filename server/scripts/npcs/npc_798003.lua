-- scripts/npcs/npc_798003.lua
-- Sanctum Flight Master — NPC template 798003.
--
-- Offers a flight-path menu. Unlike the Gatekeeper (ground teleport), the
-- Flight Master triggers an aerial flight-path cinematic and charges
-- flight-path kinah fees (traditionally cheaper than teleport scrolls).
--
-- Destinations are cached in _active_flight_paths keyed by entity_id;
-- the CM_FLIGHT_PATH_SELECT handler resolves the chosen id to coordinates.

local FLIGHT_PATHS = {
    [1] = { name = "Sanctum Plaza (air)",    world = 210010000, x = 1380, y = 1530, z = 620, price = 100  },
    [2] = { name = "Verteron Citadel (air)", world = 210020000, x = 1690, y = 1390, z = 260, price = 600  },
    [3] = { name = "Eltnen Fortress (air)",  world = 210030000, x = 1740, y = 2560, z = 400, price = 1200 },
}

dialog.register(798003, function(ctx, npc_eid, option_id)
    local gw = ctx.gateway_seq_id

    if option_id == 0 then
        -- Cache destinations so CM_FLIGHT_PATH_SELECT can resolve them.
        _active_flight_paths[ctx.entity_id] = FLIGHT_PATHS

        local options = {}
        for id, dst in pairs(FLIGHT_PATHS) do
            options[#options + 1] = {
                id   = id,
                text = dst.name .. " — " .. tostring(dst.price) .. " kinah",
            }
        end
        options[#options + 1] = { id = 0, text = "Cancel." }

        dialog.send_window(gw, npc_eid,
            "Flight Master",
            "Where shall I send you, Daeva?",
            options)

    elseif FLIGHT_PATHS[option_id] then
        -- Fallback path: client sent CM_DIALOG_SELECT instead of
        -- CM_FLIGHT_PATH_SELECT. Delegate to the same code path by
        -- running the logic inline.
        local dst = FLIGHT_PATHS[option_id]
        if dst.price and dst.price > 0 then
            if not player.spend_kinah(gw, dst.price) then
                chat.send_system(gw, "Not enough kinah.")
                return
            end
        end
        flight.set_state(ctx.entity_id, flight.STATE_FLY)
        entity.set_position(ctx.entity_id, dst.x, dst.y, dst.z, 0)

        local buf = bytes.new()
        buf:write_int32(ctx.entity_id)
        buf:write_int32(option_id)
        buf:write_float32(dst.x)
        buf:write_float32(dst.y)
        buf:write_float32(dst.z)
        player.send_packet(gw, 0x76, buf:to_string())

        _active_flight_paths[ctx.entity_id] = nil
        log.info("Flight Master: entity=" .. tostring(ctx.entity_id)
            .. " flying to " .. dst.name)
    end
end)
