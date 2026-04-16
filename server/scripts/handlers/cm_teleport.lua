-- scripts/handlers/cm_teleport.lua
-- CM_TELEPORT (0x6E): player confirmed a teleport destination from a Gatekeeper.
--
-- Payload (LE, unverified):
--   int32  destination_id   -- index into _active_teleports[ctx.entity_id]
--
-- Teleport destinations are cached per-player by the Gatekeeper NPC's dialog
-- handler into _active_teleports, mirroring the _active_shops pattern.
--
-- On success:
--   1. Consume teleport fee (kinah).
--   2. Update ECS PositionComp.
--   3. Send SM_TELEPORT_LOC to the teleported player.
--   4. Broadcast SM_TELEPORT_LOC to observers at the destination.

_active_teleports = _active_teleports or {}  -- entity_id -> {[dst_id]={name,x,y,z,price}}

local BROADCAST_RANGE = 100.0

-- --------------------------------------------------------
-- Internal: build SM_TELEPORT_LOC (0x70) packet.
-- Payload (LE, unverified):
--   int32  entity_id
--   int32  world_id
--   float  x, y, z
-- --------------------------------------------------------
local function build_teleport_packet(eid, world_id, x, y, z)
    local buf = bytes.new()
    buf:write_int32(eid)
    buf:write_int32(world_id or 0)
    buf:write_float32(x)
    buf:write_float32(y)
    buf:write_float32(z)
    return buf:to_string()
end

register_handler(0x6E, function(ctx, payload)
    local dst_id = payload:read_int32()

    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        chat.send_system(ctx.gateway_seq_id, "Cannot teleport while dead.")
        return
    end

    local tp_set = _active_teleports[ctx.entity_id]
    if not tp_set then
        chat.send_system(ctx.gateway_seq_id, "No active gatekeeper.")
        return
    end

    local dst = tp_set[dst_id]
    if not dst then
        chat.send_system(ctx.gateway_seq_id, "Unknown destination.")
        return
    end

    -- Charge fee.
    if dst.price and dst.price > 0 then
        if not player.spend_kinah(ctx.gateway_seq_id, dst.price) then
            chat.send_system(ctx.gateway_seq_id, "Not enough kinah.")
            return
        end
    end

    -- Relocate in ECS.
    entity.set_position(ctx.entity_id, dst.x, dst.y, dst.z, 0)
    local world_id = dst.world or entity.get_stat(ctx.entity_id, "world_id")

    -- Send to the teleporting player so their client runs the effect.
    local pkt = build_teleport_packet(ctx.entity_id, world_id, dst.x, dst.y, dst.z)
    player.send_packet(ctx.gateway_seq_id, 0x70, pkt)

    -- Broadcast to nearby players at the destination (they'll see the arrival).
    for _, eid in ipairs(entity.get_nearby_players(ctx.entity_id, BROADCAST_RANGE)) do
        local gw = entity.get_gateway_id(eid)
        if gw then player.send_packet(gw, 0x70, pkt) end
    end

    -- Clear session so a second click doesn't replay.
    _active_teleports[ctx.entity_id] = nil

    log.info("CM_TELEPORT: entity=" .. tostring(ctx.entity_id)
        .. " dst=" .. tostring(dst.name or dst_id)
        .. " (" .. tostring(dst.x) .. "," .. tostring(dst.y) .. "," .. tostring(dst.z) .. ")")
end)
