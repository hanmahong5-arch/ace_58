-- scripts/lib/pvp.lua
-- Phase S-11: PvP participation gate + Abyss-point kill rewards.
--
-- This module provides:
--   * pvp.FACTION_*    — faction constants.
--   * pvp.get_faction  — read the cached faction stat from ECS.
--   * pvp.is_flagged   — read the "pvp_flag" ECS stat.
--   * pvp.can_damage   — predicate used by every damage path (melee, skill, DoT
--                        trigger) to gate same-faction friendly fire.
--   * pvp.toggle_flag  — CM_PVP_FLAG_TOGGLE server action.
--   * pvp.kill_ap      — pure level-diff formula for kill rewards.
--   * pvp.award_kill_points — on_kill helper that mutates the killer's balance
--                             and emits SM_ABYSS_POINT_UPDATE.
--
-- Design notes:
--   - Faction is stored as an ECS stat "faction" on the PlayerComp entity,
--     hydrated by cm_enter_world from the character's race column. NPCs have
--     no PlayerComp so pvp.get_faction returns FACTION_NPC by default.
--   - Safe-zone damage suppression reads an ECS stat "safe_zone" that is not
--     yet written by any current handler — the hook is present for future
--     zone-manager wiring. Tests exercise it via direct stat writes.
--   - Cross-faction kills always reward AP. Same-faction duels (both sides
--     pvp-flagged) are permitted for damage but grant zero AP — duels are
--     practice, not Abyss progression.

pvp = {}

pvp.FACTION_ELYOS    = 0
pvp.FACTION_ASMODIAN = 1
pvp.FACTION_NPC      = -1

-- --- Reward tuning knobs --------------------------------------------------

-- Base abyss points awarded for an even-level PvP kill.
local BASE_KILL_AP     = 100
-- AP delta per level of difference (victim - killer).
-- Positive level diff (killing a higher-level victim) yields more AP.
local LVL_DIFF_AP_STEP = 10
-- Absolute floor to prevent zero-AP grind kills on low-level victims.
local MIN_KILL_AP      = 10
-- Absolute ceiling to keep a single kill from dwarfing Abyss grinding.
local MAX_KILL_AP      = 500

-- --- Faction accessors ----------------------------------------------------

-- pvp.get_faction(eid) -> int
-- Returns FACTION_NPC for any entity without a PlayerComp (no gateway id).
-- Returns the cached "faction" stat for players; 0 (Elyos) if unset.
pvp.get_faction = function(eid)
    if not entity.get_gateway_id(eid) then
        return pvp.FACTION_NPC
    end
    return entity.get_stat(eid, "faction")
end

-- pvp.is_flagged(eid) -> bool
-- True if the entity has voluntarily turned on its PvP participation flag.
pvp.is_flagged = function(eid)
    return entity.get_stat(eid, "pvp_flag") > 0
end

-- pvp.same_faction(a, b) -> bool
-- False if either party is an NPC (they never share a faction with players).
pvp.same_faction = function(a, b)
    local fa = pvp.get_faction(a)
    local fb = pvp.get_faction(b)
    if fa == pvp.FACTION_NPC or fb == pvp.FACTION_NPC then
        return false
    end
    return fa == fb
end

-- --- Damage gate ----------------------------------------------------------

-- pvp.can_damage(attacker_eid, target_eid) -> ok, reason
-- Reasons on false:
--   "self"                   — attacker targeted itself
--   "safe_zone"              — either party is inside a safe-zone stat
--   "same_faction_unflagged" — players of the same faction not both pvp-flagged
--
-- Every combat entry point (cm_attack, skill.use, DoT trigger) must call this
-- BEFORE invoking combat.deal_damage or damage_calc.physical.
pvp.can_damage = function(attacker, target)
    if attacker == target then
        return false, "self"
    end

    -- Safe zones block every form of damage — PvE and PvP alike.
    if entity.get_stat(target, "safe_zone") > 0
       or entity.get_stat(attacker, "safe_zone") > 0 then
        return false, "safe_zone"
    end

    local fa = pvp.get_faction(attacker)
    local fb = pvp.get_faction(target)

    -- PvE path: NPC on either side is always free to engage.
    if fa == pvp.FACTION_NPC or fb == pvp.FACTION_NPC then
        return true, nil
    end

    -- Cross-faction PvP: always permitted.
    if fa ~= fb then
        return true, nil
    end

    -- Same-faction: require BOTH parties to have pvp_flag set (duel mode).
    if pvp.is_flagged(attacker) and pvp.is_flagged(target) then
        return true, nil
    end
    return false, "same_faction_unflagged"
end

-- --- Flag toggle ---------------------------------------------------------

-- pvp.toggle_flag(eid) -> now_flagged (bool)
-- Inverts the cached "pvp_flag" ECS stat. Caller is responsible for emitting
-- SM_PVP_FLAG (0xB9) to neighbours after this returns.
pvp.toggle_flag = function(eid)
    local new_flag = 0
    if entity.get_stat(eid, "pvp_flag") <= 0 then
        new_flag = 1
    end
    entity.set_stat(eid, "pvp_flag", new_flag)
    return new_flag == 1
end

-- --- Kill-reward math ---------------------------------------------------

-- pvp.kill_ap(killer_lvl, victim_lvl) -> int
-- Pure function for testability. Clamped [MIN_KILL_AP, MAX_KILL_AP].
pvp.kill_ap = function(killer_lvl, victim_lvl)
    local diff = victim_lvl - killer_lvl
    local amount = BASE_KILL_AP + diff * LVL_DIFF_AP_STEP
    if amount < MIN_KILL_AP then amount = MIN_KILL_AP end
    if amount > MAX_KILL_AP then amount = MAX_KILL_AP end
    return amount
end

-- pvp.award_kill_points(killer_eid, victim_eid) -> amount_awarded
-- Called by on_entity_killed ONLY when the victim is a player entity.
-- Returns 0 when the kill is NPC, same-faction, or the killer is offline.
-- On a positive award: credits AP via player.add_ap and sends SM_ABYSS_POINT_UPDATE.
pvp.award_kill_points = function(killer_eid, victim_eid)
    local fk = pvp.get_faction(killer_eid)
    local fv = pvp.get_faction(victim_eid)

    -- Skip PvE kills and any NPC-involved case.
    if fk == pvp.FACTION_NPC or fv == pvp.FACTION_NPC then
        return 0
    end
    -- Same-faction duels do not feed the Abyss ladder.
    if fk == fv then
        return 0
    end

    local killer_lvl = entity.get_stat(killer_eid, "level")
    local victim_lvl = entity.get_stat(victim_eid, "level")
    if killer_lvl <= 0 then killer_lvl = 1 end
    if victim_lvl <= 0 then victim_lvl = 1 end

    local amount = pvp.kill_ap(killer_lvl, victim_lvl)

    local gw = entity.get_gateway_id(killer_eid)
    if not gw then
        return 0
    end

    -- add_ap updates the ECS cache and best-effort persists via SP.
    local ok = player.add_ap(gw, amount)
    if not ok then
        -- SP failed but cache was rolled back — do not send the packet.
        return 0
    end

    -- SM_ABYSS_POINT_UPDATE (0xBA): int64 new_total, int64 delta.
    local new_total = entity.get_stat(killer_eid, "abyss_points")
    local buf = bytes.new()
    buf:write_int64(math.floor(new_total))
    buf:write_int64(amount)
    player.send_packet(gw, 0xBA, buf:to_string())

    return amount
end
