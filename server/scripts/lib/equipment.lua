-- scripts/lib/equipment.lua
-- Phase S-12: equipment slot manager.
--
-- State model: each equipped slot is a single ECS stat on the player entity
-- named "equip_slot_1" .. "equip_slot_15" holding the item_id (0 = empty).
-- Aggregated bonuses live in "equip_attack" / "equip_defense" / "equip_hp_bonus".
-- Using ECS stats (rather than a new component) keeps the persistence model
-- identical to S-8 kinah and S-11 abyss_points — no bridge changes required.
--
-- damage_calc.physical reads "equip_attack" as a flat additive base bonus.
-- Future phases layer in proc effects (elemental damage, lifesteal) by
-- stacking additional stat keys such as "equip_fire_dmg".
--
-- Contract:
--   equipment.SLOT_*                — slot id constants
--   equipment.SLOT_COUNT            — total slot count (15)
--   equipment.equip(eid, item_id) -> ok, reason | slot
--     reasons: "unknown_item" | "not_equippable" | "bad_slot" | "low_level"
--   equipment.unequip(eid, slot) -> ok, reason
--     reasons: "bad_slot" | "empty"
--   equipment.get_slot(eid, slot) -> item_id (0 if empty)
--   equipment.get_equipped(eid) -> { [slot]=item_id, ... }
--   equipment.recompute(eid)        — rebuild equip_attack/defense/hp_bonus
--   equipment.is_valid_slot(slot) -> bool

equipment = {}

equipment.SLOT_MAIN_HAND = 1
equipment.SLOT_SUB_HAND  = 2
equipment.SLOT_HELMET    = 3
equipment.SLOT_CHEST     = 4
equipment.SLOT_GLOVES    = 5
equipment.SLOT_BOOTS     = 6
equipment.SLOT_NECKLACE  = 7
equipment.SLOT_EARRING_L = 8
equipment.SLOT_EARRING_R = 9
equipment.SLOT_RING_L    = 10
equipment.SLOT_RING_R    = 11
equipment.SLOT_BELT      = 12
equipment.SLOT_SHOULDER  = 13
equipment.SLOT_PANTS     = 14
equipment.SLOT_WINGS     = 15

equipment.SLOT_COUNT = 15

-- --- Internal helpers ----------------------------------------------------

local function slot_stat_key(slot)
    return "equip_slot_" .. tostring(slot)
end

equipment.is_valid_slot = function(slot)
    return type(slot) == "number" and slot >= 1 and slot <= equipment.SLOT_COUNT
end

-- equipment.get_slot(eid, slot) -> item_id
-- Returns the item_id occupying the slot, or 0 if empty / invalid.
equipment.get_slot = function(eid, slot)
    if not equipment.is_valid_slot(slot) then
        return 0
    end
    return entity.get_stat(eid, slot_stat_key(slot))
end

-- equipment.get_equipped(eid) -> { [slot]=item_id } (only non-zero entries)
equipment.get_equipped = function(eid)
    local result = {}
    for slot = 1, equipment.SLOT_COUNT do
        local iid = entity.get_stat(eid, slot_stat_key(slot))
        if iid > 0 then
            result[slot] = iid
        end
    end
    return result
end

-- equipment.recompute(eid)
-- Rebuilds equip_attack / equip_defense / equip_hp_bonus from the current
-- slot contents. Call after every equip / unequip mutation. Idempotent.
equipment.recompute = function(eid)
    if not items then
        -- items registry not loaded: leave bonuses at zero.
        entity.set_stat(eid, "equip_attack",   0)
        entity.set_stat(eid, "equip_defense",  0)
        entity.set_stat(eid, "equip_hp_bonus", 0)
        return
    end

    local total_atk, total_def, total_hp = 0, 0, 0
    for slot = 1, equipment.SLOT_COUNT do
        local iid = entity.get_stat(eid, slot_stat_key(slot))
        if iid > 0 then
            local tmpl = items.get(iid)
            if tmpl then
                total_atk = total_atk + (tmpl.attack   or 0)
                total_def = total_def + (tmpl.defense  or 0)
                total_hp  = total_hp  + (tmpl.hp_bonus or 0)
            end
        end
    end
    entity.set_stat(eid, "equip_attack",   total_atk)
    entity.set_stat(eid, "equip_defense",  total_def)
    entity.set_stat(eid, "equip_hp_bonus", total_hp)
end

-- equipment.equip(eid, item_id) -> ok, reason_or_slot
-- Validates the template, level requirement, and slot. Replaces any existing
-- item in the destination slot (auto-unequip semantics). Returns the slot
-- index on success, or false + reason string on failure.
equipment.equip = function(eid, item_id)
    if not items then
        return false, "unknown_item"
    end
    local tmpl = items.get(item_id)
    if not tmpl then
        return false, "unknown_item"
    end

    local slot = tmpl.slot or 0
    if slot <= 0 then
        return false, "not_equippable"
    end
    if not equipment.is_valid_slot(slot) then
        return false, "bad_slot"
    end

    local req = tmpl.required_level or 0
    if req > 0 then
        local lvl = entity.get_stat(eid, "level")
        if lvl < req then
            return false, "low_level"
        end
    end

    -- Replace existing content unconditionally (auto-unequip previous item).
    entity.set_stat(eid, slot_stat_key(slot), item_id)
    equipment.recompute(eid)
    return true, slot
end

-- equipment.unequip(eid, slot) -> ok, reason
-- Clears the slot to 0 and recomputes bonuses. Returns false, "empty" if the
-- slot was already empty so callers can surface a client-facing message.
equipment.unequip = function(eid, slot)
    if not equipment.is_valid_slot(slot) then
        return false, "bad_slot"
    end
    local key = slot_stat_key(slot)
    local iid = entity.get_stat(eid, key)
    if iid <= 0 then
        return false, "empty"
    end
    entity.set_stat(eid, key, 0)
    equipment.recompute(eid)
    return true, iid
end
