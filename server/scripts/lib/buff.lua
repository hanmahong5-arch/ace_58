-- scripts/lib/buff.lua
-- High-level buff/DoT wrapper with SM_BUFF_INFO (0x3C) broadcast.
--
-- Use buff.apply / buff.apply_dot instead of combat.apply_buff / combat.apply_dot
-- when you want nearby players to see the buff visual effect.
--
-- SM_BUFF_INFO payload (LE, unverified):
--   int32 target_entity_id
--   int32 buff_id           (positive = buff, -1 = generic DoT)
--   int32 duration_ticks

buff = {}

local BROADCAST_RANGE = 200.0

-- --------------------------------------------------------
-- Internal: broadcasts SM_BUFF_INFO (0x3C) to the target and nearby observers.
-- --------------------------------------------------------
local function broadcast_buff_info(target_id, buff_id, duration_ticks)
    local buf = bytes.new()
    buf:write_int32(target_id)
    buf:write_int32(buff_id)
    buf:write_int32(math.floor(duration_ticks))
    local pkt = buf:to_string()

    -- Send to the buffed entity (if player)
    local gw = entity.get_gateway_id(target_id)
    if gw then player.send_packet(gw, 0x3C, pkt) end

    -- Send to nearby observers
    local nearby = entity.get_nearby(target_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local ngw = entity.get_gateway_id(nid)
        if ngw then player.send_packet(ngw, 0x3C, pkt) end
    end
end

-- --------------------------------------------------------
-- buff.apply(target_id, buff_id, duration_ticks)
-- Applies a non-damaging buff and broadcasts SM_BUFF_INFO.
-- duration_ticks is relative to current_tick (converted to absolute by bridge).
-- --------------------------------------------------------
buff.apply = function(target_id, buff_id, duration_ticks)
    combat.apply_buff(target_id, buff_id, duration_ticks)
    broadcast_buff_info(target_id, buff_id, duration_ticks)
end

-- --------------------------------------------------------
-- buff.apply_dot(target_id, dmg_per_tick, duration_ticks, element)
-- Applies a DoT and broadcasts SM_BUFF_INFO with buff_id = -1 (generic DoT icon).
-- duration_ticks is relative to current_tick.
-- --------------------------------------------------------
buff.apply_dot = function(target_id, dmg_per_tick, duration_ticks, element)
    combat.apply_dot(target_id, dmg_per_tick, duration_ticks, element or "physical")
    broadcast_buff_info(target_id, -1, duration_ticks)
end
