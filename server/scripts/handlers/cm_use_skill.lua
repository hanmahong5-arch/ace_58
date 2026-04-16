-- scripts/handlers/cm_use_skill.lua
-- CM_USE_SKILL (0x0E): client requests a skill activation.
--
-- Payload (binary, little-endian):
--   int32  skill_id     -- numeric skill template ID
--   int32  target_id    -- ECS entity ID of the primary target (0 = self / AoE)
--   byte   skill_level  -- current skill level (1-based; reserved for future scaling)
--
-- NOTE: CM_USE_SKILL wire format is unverified; adjust after packet capture.

register_handler(0x0E, function(ctx, payload)
    local skill_id   = payload:read_int32()
    local target_id  = payload:read_int32()
    local _skill_lvl = payload:read_byte()   -- reserved

    log.info("CM_USE_SKILL entity=" .. tostring(ctx.entity_id)
        .. " skill_id=" .. tostring(skill_id)
        .. " target=" .. tostring(target_id))

    -- Guard: skill registry must be loaded (lib/skill.lua)
    if not skill then
        log.warn("CM_USE_SKILL: skill registry not loaded, dropping")
        return
    end

    -- Dead entities cannot use skills.
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    -- Dispatch through the skill registry.
    -- skill.use returns: true on success, or false + reason string on rejection.
    local ok, reason = skill.use(ctx, skill_id, target_id)
    if not ok then
        -- SM_SKILL_FAILED (0x90) reason codes:
        --   1=cooldown, 2=no_mp, 3=range, 4=unknown, 5=pvp_blocked
        -- Phase S-11: same_faction_unflagged / safe_zone / self all collapse
        -- to code 5 (pvp_blocked) so the 5.8 client can render a single error
        -- string for all friendly-fire rejections.
        local reason_code = ({
            cooldown                = 1,
            no_mp                   = 2,
            range                   = 3,
            same_faction_unflagged  = 5,
            safe_zone               = 5,
            self                    = 5,
        })[reason or ""] or 4
        local fail_buf = bytes.new()
        fail_buf:write_int32(ctx.entity_id)
        fail_buf:write_int32(skill_id)
        fail_buf:write_byte(reason_code)
        player.send_packet(ctx.gateway_seq_id, 0x90, fail_buf:to_string())
        log.info("CM_USE_SKILL: rejected skill_id=" .. tostring(skill_id)
            .. " entity=" .. tostring(ctx.entity_id)
            .. " reason=" .. tostring(reason))
    end
end)
