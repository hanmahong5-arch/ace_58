-- scripts/handlers/cm_move.lua
-- CM_MOVE (0x0A): client sends its current position and movement vector.
--
-- Payload (binary, little-endian):
--   float32  x, y, z        — current world position
--   byte     heading         — facing direction (0-255)
--   byte     move_type       — 0=stop, 1=walk, 2=run, 3=glide
--
-- Server action:
--   1. Update the entity's ECS PositionComp.
--   2. Broadcast SM_MOVE (0x4C) to all players within BROADCAST_RANGE metres.
--
-- SM_MOVE payload (broadcast, LE):
--   int32    entity_id       — ECS entity ID (object identifier for this session)
--   float32  x, y, z
--   byte     heading
--   byte     move_type
--
-- NOTE: The SM_MOVE wire format is unverified; adjust after packet capture.

local BROADCAST_RANGE = 200.0  -- metres; AION standard visibility radius

register_handler(0x0A, function(ctx, payload)
    local x         = payload:read_float32()
    local y         = payload:read_float32()
    local z         = payload:read_float32()
    local heading   = payload:read_byte()
    local move_type = payload:read_byte()

    -- Update this entity's position in ECS.
    entity.set_position(ctx.entity_id, x, y, z, heading)

    -- Build SM_MOVE packet once; broadcast to all nearby player sessions.
    local buf = bytes.new()
    buf:write_int32(ctx.entity_id)
    buf:write_float32(x)
    buf:write_float32(y)
    buf:write_float32(z)
    buf:write_byte(heading)
    buf:write_byte(move_type)
    local pkt = buf:to_string()

    local nearby = entity.get_nearby(ctx.entity_id, BROADCAST_RANGE)
    for _, nid in ipairs(nearby) do
        local gw = entity.get_gateway_id(nid)
        if gw then
            player.send_packet(gw, 0x4C, pkt)
        end
    end
end)
