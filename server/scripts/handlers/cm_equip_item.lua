-- scripts/handlers/cm_equip_item.lua
-- CM_EQUIP_ITEM (0xBB): client equips an inventory item into its slot.
--
-- Payload (LE):
--   int32 item_id    — template id of the item to equip
--   byte  slot_hint  — reserved; server derives the slot from the template
--
-- The server-authoritative slot comes from items.get(item_id).slot; the
-- byte in the payload is accepted for wire-compat but ignored — the client
-- cannot pick an arbitrary destination slot.
--
-- Side effects on success:
--   1. equipment.equip updates the slot stat and recomputes equip_attack /
--      equip_defense / equip_hp_bonus.
--   2. SM_EQUIPMENT_CHANGED (0xBD) broadcast to self + nearby players.
--
-- Failure reasons (from equipment.equip) are logged; the client is not
-- notified via SM_SKILL_FAILED here because the 5.8 client displays a
-- generic "cannot equip" message on packet absence.

local BROADCAST_RANGE = 200.0

local function broadcast_change(eid, slot, item_id)
    local buf = bytes.new()
    buf:write_int32(eid)
    buf:write_byte(slot)
    buf:write_int32(item_id)
    local pkt = buf:to_string()

    local self_gw = entity.get_gateway_id(eid)
    if self_gw then player.send_packet(self_gw, 0xBD, pkt) end

    local nearby = entity.get_nearby_players(eid, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local gw = entity.get_gateway_id(nid)
        if gw then player.send_packet(gw, 0xBD, pkt) end
    end
end

register_handler(0xBB, function(ctx, payload)
    local item_id   = payload:read_int32()
    local _slot_hint = payload:read_byte()  -- reserved, server-authoritative

    if not equipment then
        log.warn("CM_EQUIP_ITEM: equipment lib not loaded, dropping")
        return
    end

    -- Dead players cannot change gear (matches NCSoft client-side block).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local ok, reason_or_slot = equipment.equip(ctx.entity_id, item_id)
    if not ok then
        log.info("CM_EQUIP_ITEM: rejected entity=" .. tostring(ctx.entity_id)
            .. " item_id=" .. tostring(item_id)
            .. " reason=" .. tostring(reason_or_slot))
        return
    end

    local slot = reason_or_slot
    broadcast_change(ctx.entity_id, slot, item_id)

    log.info("CM_EQUIP_ITEM: entity=" .. tostring(ctx.entity_id)
        .. " item_id=" .. tostring(item_id)
        .. " slot=" .. tostring(slot))
end)
