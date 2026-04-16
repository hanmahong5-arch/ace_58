-- scripts/handlers/cm_unequip_item.lua
-- CM_UNEQUIP_ITEM (0xBC): client removes an item from an equipment slot.
--
-- Payload (LE):
--   byte slot   — which equipment.SLOT_* to clear
--
-- Side effects on success:
--   1. equipment.unequip clears the slot stat + recomputes bonuses.
--   2. SM_EQUIPMENT_CHANGED (0xBD) broadcast with item_id=0.

local BROADCAST_RANGE = 200.0

register_handler(0xBC, function(ctx, payload)
    local slot = payload:read_byte()

    if not equipment then
        log.warn("CM_UNEQUIP_ITEM: equipment lib not loaded, dropping")
        return
    end

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local ok, reason = equipment.unequip(ctx.entity_id, slot)
    if not ok then
        log.info("CM_UNEQUIP_ITEM: rejected entity=" .. tostring(ctx.entity_id)
            .. " slot=" .. tostring(slot)
            .. " reason=" .. tostring(reason))
        return
    end

    -- Broadcast slot now empty.
    local buf = bytes.new()
    buf:write_int32(ctx.entity_id)
    buf:write_byte(slot)
    buf:write_int32(0)
    local pkt = buf:to_string()

    player.send_packet(ctx.gateway_seq_id, 0xBD, pkt)
    local nearby = entity.get_nearby_players(ctx.entity_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local gw = entity.get_gateway_id(nid)
        if gw then player.send_packet(gw, 0xBD, pkt) end
    end

    log.info("CM_UNEQUIP_ITEM: entity=" .. tostring(ctx.entity_id)
        .. " slot=" .. tostring(slot))
end)
