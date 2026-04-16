-- scripts/lib/skill.lua
-- Skill registry and dispatch framework.
--
-- Each skill is defined in scripts/skills/skill_XXXX.lua and registered via
-- skill.register({ id=..., name=..., cooldown=..., mp_cost=..., on_use=fn }).
--
-- Usage:
--   skill.register(def)              -- called at script load time
--   skill.use(ctx, skill_id, target_id) -> bool  -- called by CM_USE_SKILL handler
--
-- Cooldown state is stored in Lua (_cooldowns table).
-- This state resets on hot-reload — acceptable for development.
-- For persistent cooldowns across reconnects use ECS stats in a future phase.

skill = {}

local _registry  = {}
local _cooldowns = {}   -- key: "entity_id_skill_id" -> expires_at_tick

-- Ticks per second assumed for cooldown conversion.
local TICK_RATE = 20

-- --------------------------------------------------------
-- skill.register(def): declare a skill definition.
-- def fields:
--   id         (number, required) unique skill template ID
--   name       (string, optional) display name
--   cooldown   (number, optional) cooldown in seconds; 0 = no cooldown
--   mp_cost    (number, optional) MP consumed on use; 0 = free
--   range      (number, optional) max use range in metres; 0 = unlimited
--   on_use     (function, optional) fn(ctx, target_id) — main skill logic
-- --------------------------------------------------------
skill.register = function(def)
    if not def or not def.id then
        log.warn("skill.register: missing id in definition")
        return
    end
    _registry[def.id] = def
end

-- --------------------------------------------------------
-- skill.use(ctx, skill_id, target_id) -> bool
-- Validates and executes a skill.
-- Returns true on success, false on cooldown / insufficient MP / unknown skill.
-- --------------------------------------------------------
-- skill.use(ctx, skill_id, target_id) -> ok [, reason]
-- Returns true on success.
-- Returns false, reason_string on failure:
--   "unknown"  — skill_id not registered
--   "cooldown" — still on cooldown
--   "no_mp"    — insufficient MP
skill.use = function(ctx, skill_id, target_id)
    local def = _registry[skill_id]
    if not def then
        log.warn("skill.use: unknown skill_id=" .. tostring(skill_id))
        return false, "unknown"
    end

    -- Cooldown check (current_tick may be nil before first on_tick fires)
    local cd_key = tostring(ctx.entity_id) .. "_" .. tostring(skill_id)
    local expires = _cooldowns[cd_key] or 0
    if current_tick and current_tick < expires then
        return false, "cooldown"
    end

    -- Phase S-11: PvP gate for targeted offensive skills.
    -- Skills with target_id == 0 are self-buffs / AoE and bypass this check
    -- (AoE filtering happens per-target inside the skill's on_use body).
    if pvp and target_id and target_id > 0 and target_id ~= ctx.entity_id then
        local ok, reason = pvp.can_damage(ctx.entity_id, target_id)
        if not ok then
            return false, reason
        end
    end

    -- MP cost check
    local mp_cost = def.mp_cost or 0
    if mp_cost > 0 then
        local mp = entity.get_stat(ctx.entity_id, "mp")
        if mp < mp_cost then
            return false, "no_mp"
        end
        entity.set_stat(ctx.entity_id, "mp", mp - mp_cost)
    end

    -- Register cooldown
    local cooldown_sec = def.cooldown or 0
    if cooldown_sec > 0 and current_tick then
        _cooldowns[cd_key] = current_tick + math.floor(cooldown_sec * TICK_RATE)
    end

    -- Dispatch
    if def.on_use then
        def.on_use(ctx, target_id)
    end

    return true
end
