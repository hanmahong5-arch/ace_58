-- scripts/combat/damage_calc.lua
-- Damage and hit-chance formulas for physical and magical combat.
--
-- Depends on entity.* and combat.* bridge APIs.
-- All functions are stateless and operate on entity_id pairs.
--
-- Phase S-4: level-scaling formula only.
-- Phase S-5: replace with full stat model (attack, defense, crit rating, resists).

damage_calc = {}

-- Base physical damage per level at level 1.
local BASE_DMG_LV1  = 10
-- Damage growth per level.
local DMG_PER_LEVEL = 5
-- Critical hit multiplier.
local CRIT_MULT     = 2.0
-- Critical hit base chance.
local CRIT_CHANCE   = 0.10

-- --------------------------------------------------------
-- damage_calc.physical(attacker_id, target_id) -> amount
-- Returns the final damage to apply, after level-diff reduction.
-- Calls combat.deal_damage internally; returns actual HP removed.
-- --------------------------------------------------------
damage_calc.physical = function(attacker_id, target_id)
    local atk_lvl = entity.get_stat(attacker_id, "level")
    if atk_lvl <= 0 then atk_lvl = 1 end

    -- Base damage scaled by attacker level.
    local base = BASE_DMG_LV1 + atk_lvl * DMG_PER_LEVEL

    -- Phase S-12: equipped weapon adds flat bonus.
    -- equip_attack is maintained by equipment.recompute() on equip/unequip.
    local equip_atk = entity.get_stat(attacker_id, "equip_attack")
    if equip_atk > 0 then
        base = base + equip_atk
    end

    -- Level-difference penalty/bonus: -5 % per level above target, +5 % per level below.
    local def_lvl = entity.get_stat(target_id, "level")
    if def_lvl <= 0 then def_lvl = 1 end
    local lvl_factor = 1.0 + (def_lvl - atk_lvl) * 0.05
    if lvl_factor < 0.5 then lvl_factor = 0.5 end   -- floor: never below 50 %
    if lvl_factor > 1.5 then lvl_factor = 1.5 end   -- cap: never above 150 %

    local amount = math.floor(base * lvl_factor)

    -- Crit roll.
    local is_crit = math.random() < CRIT_CHANCE
    if is_crit then
        amount = math.floor(amount * CRIT_MULT)
    end

    -- Apply to ECS and return remaining HP.
    local remaining = combat.deal_damage(attacker_id, target_id, amount, "physical")
    return amount, remaining, is_crit
end

-- --------------------------------------------------------
-- damage_calc.check_hit(attacker_id, target_id) -> bool
-- Pure-Lua hit check using math.random().  Use instead of combat.check_hit
-- when the Lua script needs the result before calling deal_damage.
-- --------------------------------------------------------
damage_calc.check_hit = function(attacker_id, target_id)
    local atk_lvl = entity.get_stat(attacker_id, "level")
    local def_lvl = entity.get_stat(target_id,   "level")
    local chance  = 0.80 + (atk_lvl - def_lvl) * 0.02
    chance = math.max(0.10, math.min(0.95, chance))
    return math.random() < chance
end
