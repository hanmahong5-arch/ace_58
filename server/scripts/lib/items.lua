-- scripts/lib/items.lua
-- Phase S-12: item template registry.
--
-- Hot-reloadable static data describing every item type. Skill/shop/equipment
-- logic looks up templates here by item_id to read slot compatibility, stat
-- bonuses, and level requirements.
--
-- Production deployments should migrate these tables into aion_world_live via
-- an `items_template` seed; for S-12 the MVP is declarative Lua so skill and
-- equipment unit tests are self-contained.
--
-- Template schema:
--   id                (int)    unique item id (matches NCSoft item_templates id)
--   name              (string) display name (ASCII for tests)
--   slot              (int)    equipment.SLOT_* or 0 for non-equippable
--   required_level    (int)    minimum player level to equip; 0 = no check
--   attack            (int)    flat bonus to equip_attack when equipped
--   defense           (int)    flat bonus to equip_defense
--   hp_bonus          (int)    flat bonus to max_hp (not applied to current hp)
--   description       (string) flavor text (unused by runtime)
--
-- Lookup contract:
--   items.get(item_id) -> template_table | nil
--   items.is_equippable(item_id) -> bool
--   items.register(template) -> bool        (for runtime additions by tests)

items = {}

local _registry = {}

-- --- Slot constants must match equipment.SLOT_* — redeclared locally so this
--     module does not depend on load-order (equipment.lua loads after items).
local SLOT_MAIN_HAND = 1
local SLOT_SUB_HAND  = 2
local SLOT_HELMET    = 3
local SLOT_CHEST     = 4
local SLOT_GLOVES    = 5
local SLOT_BOOTS     = 6
local SLOT_NECKLACE  = 7
local SLOT_EARRING_L = 8
local SLOT_EARRING_R = 9
local SLOT_RING_L    = 10
local SLOT_RING_R    = 11
local SLOT_BELT      = 12
local SLOT_SHOULDER  = 13
local SLOT_PANTS     = 14
local SLOT_WINGS     = 15

-- --- Public API -----------------------------------------------------------

items.register = function(tmpl)
    if type(tmpl) ~= "table" or type(tmpl.id) ~= "number" then
        return false
    end
    _registry[tmpl.id] = tmpl
    return true
end

items.get = function(item_id)
    return _registry[item_id]
end

items.is_equippable = function(item_id)
    local t = _registry[item_id]
    return t ~= nil and (t.slot or 0) > 0
end

-- --- Seed the MVP catalogue ----------------------------------------------
-- Ten demo items covering weapon, armor, and accessory slots. Bonuses are
-- tuned so that a level-10 player fully geared gains +150 attack and +90
-- defense — enough to make equip/unequip observable in combat tests.

items.register({ id = 100001, name = "Wooden Sword",   slot = SLOT_MAIN_HAND, required_level = 1,  attack = 30, defense = 0,  hp_bonus = 0 })
items.register({ id = 100002, name = "Iron Sword",     slot = SLOT_MAIN_HAND, required_level = 10, attack = 80, defense = 0,  hp_bonus = 0 })
items.register({ id = 100003, name = "Wooden Shield",  slot = SLOT_SUB_HAND,  required_level = 1,  attack = 0,  defense = 20, hp_bonus = 0 })
items.register({ id = 100004, name = "Leather Helmet", slot = SLOT_HELMET,    required_level = 1,  attack = 0,  defense = 10, hp_bonus = 20 })
items.register({ id = 100005, name = "Leather Tunic",  slot = SLOT_CHEST,     required_level = 1,  attack = 0,  defense = 25, hp_bonus = 50 })
items.register({ id = 100006, name = "Leather Gloves", slot = SLOT_GLOVES,    required_level = 1,  attack = 2,  defense = 8,  hp_bonus = 10 })
items.register({ id = 100007, name = "Leather Boots",  slot = SLOT_BOOTS,     required_level = 1,  attack = 0,  defense = 10, hp_bonus = 15 })
items.register({ id = 100008, name = "Copper Ring",    slot = SLOT_RING_L,    required_level = 1,  attack = 5,  defense = 0,  hp_bonus = 10 })
items.register({ id = 100009, name = "Amulet",         slot = SLOT_NECKLACE,  required_level = 1,  attack = 0,  defense = 5,  hp_bonus = 30 })
-- Non-equippable potion — used by negative tests.
items.register({ id = 200001, name = "Healing Potion", slot = 0, required_level = 0, attack = 0, defense = 0, hp_bonus = 0 })
