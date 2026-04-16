-- scripts/events/tick.lua
-- Track E (Rust) world-engine tick entry point.
-- Loaded by ACE_5.8_RS world binary at startup if present.
--
-- This file is intentionally different from events/on_tick.lua (Track A / Go).
-- Track A's on_tick.lua registers Go-specific host APIs (entity.get_gateway_id,
-- player.send_packet via NATS, etc.) that are not available in Track E's mlua VM.
--
-- Track E milestone E-4 will replace these stubs with real ECS-wired functions
-- once the entity registry and reverse packet channel are implemented.
--
-- Called from: world/src/main.rs  ecs_tick_loop()
--   vm.call::<i64, ()>("on_tick", tick_count as i64)
-- Requires: register_host_apis() called before exec_file("events/tick.lua")

-- Heartbeat interval in ticks (20 Hz → 200 ticks ≈ 10 seconds)
local HEARTBEAT_INTERVAL = 200

-- IMPORTANT: `events/on_tick.lua` already defines a full Track-A on_tick that
-- advances `current_tick`, drives regen, DoT ticking and patrol AI. Because
-- loadScripts walks both files in a single flat pass (alphabetical order puts
-- on_tick.lua BEFORE tick.lua), an unconditional `function on_tick(tick)` in
-- this file would SILENTLY OVERWRITE the Track-A implementation and leave
-- `current_tick` frozen at 0 — breaking skill cooldowns, buff expiry, and
-- every test that calls on_tick(n).
--
-- Track E (Rust mlua) calls this file directly at startup and is the only
-- loader that should wire `on_tick` from here. We therefore install the
-- Track E placeholder only if no previous script has already defined it.
if on_tick == nil then
    function on_tick(tick)
        -- Periodic heartbeat log so ops can see the Lua tick is alive.
        if tick % HEARTBEAT_INTERVAL == 0 then
            log.info("Track E tick heartbeat tick=" .. tostring(tick)
                .. " (~" .. tostring(tick / 20) .. "s)")
        end

        -- E-4 placeholder: once entity.get_all_players() returns real data,
        -- this block will drive HP/MP/FP regeneration for each online player.
        -- local players = entity.get_all_players()
        -- for _, p in ipairs(players) do ... end
    end
end
