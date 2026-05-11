-- scripts/handlers/cm_revive.lua
-- CM_REVIVE_REQUEST (0x56): client requests character resurrection after death.
-- Revives the player at their current position with partial HP/MP/FP.
--
-- Phase S-5: revive-in-place at 25 % of max stats.
-- Phase S-6: teleport to bind-point via aion_GetBindPoint (see body).
--
-- SM_REVIVE payload (LE, unverified):
--   byte   result       -- 0 = success
--   int32  entity_id
--   float32 x, y, z    -- revive position
--
-- NOTE: CM_REVIVE_REQUEST opcode (0x56) and SM_REVIVE (0x7A) are unverified.

local REVIVE_HP_PCT = 0.25
local REVIVE_MP_PCT = 0.25
local REVIVE_FP_PCT = 0.25

register_handler(0x56, function(ctx, payload)
    -- Only allow if currently dead.
    if entity.get_stat(ctx.entity_id, "dead") <= 0 then
        return
    end

    local max_hp = entity.get_stat(ctx.entity_id, "max_hp")
    local max_mp = entity.get_stat(ctx.entity_id, "max_mp")
    local max_fp = entity.get_stat(ctx.entity_id, "max_fp")

    -- Restore partial stats.
    entity.set_stat(ctx.entity_id, "hp", math.max(1, math.floor(max_hp * REVIVE_HP_PCT)))
    entity.set_stat(ctx.entity_id, "mp", math.max(1, math.floor(max_mp * REVIVE_MP_PCT)))
    entity.set_stat(ctx.entity_id, "fp", math.max(1, math.floor(max_fp * REVIVE_FP_PCT)))
    entity.set_stat(ctx.entity_id, "dead", 0)

    -- Determine revive position: prefer bind point from DB, fall back to current.
    local pos = entity.get_position(ctx.entity_id)
    local rx, ry, rz = pos.x or 0, pos.y or 0, pos.z or 0

    local char_id = entity.get_stat(ctx.entity_id, "char_id")
    if char_id > 0 then
        local bind_rows, bind_err = db.call("aion_GetBindPoint", char_id)
        if not bind_err and bind_rows and #bind_rows > 0 then
            rx = bind_rows[1].xlocation or rx
            ry = bind_rows[1].ylocation or ry
            rz = bind_rows[1].zlocation or rz
            entity.set_position(ctx.entity_id, rx, ry, rz)
            log.info("CM_REVIVE: using bind point (" .. rx .. "," .. ry .. "," .. rz .. ")")
        end
    end

    -- SM_REVIVE (0x7A): allow the client to move again.
    local rvbuf = bytes.new()
    rvbuf:write_byte(0)                         -- result: 0 = success
    rvbuf:write_int32(ctx.entity_id)
    rvbuf:write_float32(rx)
    rvbuf:write_float32(ry)
    rvbuf:write_float32(rz)
    player.send_packet(ctx.gateway_seq_id, 0x7A, rvbuf:to_string())

    -- SM_STAT_INFO (0x1E): sync HP/MP/FP bars immediately after revive.
    local statbuf = bytes.new()
    statbuf:write_int32(ctx.entity_id)
    statbuf:write_int32(math.floor(entity.get_stat(ctx.entity_id, "hp")))
    statbuf:write_int32(math.floor(max_hp))
    statbuf:write_int32(math.floor(entity.get_stat(ctx.entity_id, "mp")))
    statbuf:write_int32(math.floor(max_mp))
    statbuf:write_int32(math.floor(entity.get_stat(ctx.entity_id, "fp")))
    statbuf:write_int32(math.floor(max_fp))
    player.send_packet(ctx.gateway_seq_id, 0x1E, statbuf:to_string())

    log.info("CM_REVIVE: entity=" .. tostring(ctx.entity_id) .. " revived")
end)
