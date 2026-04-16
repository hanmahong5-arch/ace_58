-- scripts/ai/patrol.lua
-- Basic NPC patrol behaviour: random walk within a radius of the spawn point.
--
-- State is stored in ECS stats to survive hot-reload:
--   spawn_x / spawn_y / spawn_z  — origin of the patrol area (set at spawn time)
--   patrol_range                 — max wander radius in metres (default 20)
--   patrol_next_tick             — tick number when the next move fires
--
-- Usage (from on_tick.lua):
--   patrol.step(nid, tick)

patrol = {}

-- How many ticks between each position update (at 20 ticks/sec: 40 = 2 s).
local PATROL_STEP_INTERVAL = 40

-- --------------------------------------------------------
-- patrol.step(entity_id, tick): advance one AI step.
-- Called every game tick; uses tick gating to throttle movement.
-- --------------------------------------------------------
patrol.step = function(nid, tick)
    -- Gate: only move once per PATROL_STEP_INTERVAL ticks.
    -- Each NPC gets a per-entity offset to spread load across ticks.
    local offset = nid % PATROL_STEP_INTERVAL
    if tick % PATROL_STEP_INTERVAL ~= offset then return end

    local spawn_x = entity.get_stat(nid, "spawn_x")
    local spawn_y = entity.get_stat(nid, "spawn_y")
    local spawn_z = entity.get_stat(nid, "spawn_z")
    local range   = entity.get_stat(nid, "patrol_range")
    if range <= 0 then range = 20 end

    -- Choose a random point within the circular patrol area (polar coordinates).
    local angle = math.random() * 2 * math.pi
    local dist  = math.random() * range
    local new_x = spawn_x + dist * math.cos(angle)
    local new_y = spawn_y + dist * math.sin(angle)

    -- Move toward the chosen point; heading is derived from the movement direction.
    local heading = math.floor((angle / (2 * math.pi)) * 255) % 256
    entity.set_position(nid, new_x, new_y, spawn_z, heading)
end
