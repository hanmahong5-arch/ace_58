-- scripts/handlers/cm_instance_enter.lua
-- CM_INSTANCE_ENTER (0xCF): party leader (or solo player) requests instance entry.
--
-- Payload (LE):
--   int32 template_id
--
-- Response: SM_INSTANCE_ENTER_RESULT (0xD0)
--   byte result  (see instance.R_* constants)
--   int64 run_id (0 on failure)
--   int32 cooldown_remaining_sec (>0 when result=1)
--
-- If the caller already has a live _char_run for this template the handler
-- rejoins the existing run rather than creating a fresh one — this is how
-- reconnect-after-disconnect works (cooldown already burned at first entry).

local function send_result(gw, result, run_id, cooldown_sec)
    local buf = bytes.new()
    buf:write_byte(result)
    buf:write_int64(run_id or 0)
    buf:write_int32(cooldown_sec or 0)
    player.send_packet(gw, 0xD0, buf:to_string())
end

local function reason_to_code(reason)
    if reason == "cooldown"              then return instance.R_COOLDOWN          end
    if reason == "bad_level"             then return instance.R_BAD_LEVEL         end
    if reason == "bad_group_size"        then return instance.R_BAD_GROUP_SIZE    end
    if reason == "not_leader"            then return instance.R_NOT_LEADER        end
    if reason == "already_in_instance"   then return instance.R_ALREADY_IN_INSTANCE end
    if reason == "template_unknown"      then return instance.R_TEMPLATE_UNKNOWN  end
    -- Remaining reasons (db_error, member_offline, member_dead, member_out_of_range,
    -- member_no_char_id) all map to generic DB_ERROR from the client's perspective.
    return instance.R_DB_ERROR
end

register_handler(0xCF, function(ctx, payload)
    local template_id = payload:read_int32()
    local gw          = ctx.gateway_seq_id
    local eid         = ctx.entity_id

    -- Try rejoin first — if this character still owns a run for the same
    -- template, no cooldown is re-charged.
    local cid = math.floor(entity.get_stat(eid, "char_id") or 0)
    local existing = instance.has_char_run(cid)
    if existing then
        local inst = instance.get(existing)
        if inst and inst.template_id == template_id
           and inst.state ~= instance.STATE_EXPIRED then
            local ok, rejoin_reason = instance.rejoin(eid, template_id)
            if ok then
                send_result(gw, instance.R_OK, existing, 0)
                return
            end
            log.warn("CM_INSTANCE_ENTER: rejoin failed reason="
                .. tostring(rejoin_reason))
        end
    end

    local run_id, reason, blocking_cid = instance.create(eid, template_id)
    if run_id then
        send_result(gw, instance.R_OK, run_id, 0)
        return
    end

    local code = reason_to_code(reason)
    local cooldown_remaining = 0
    if code == instance.R_COOLDOWN and blocking_cid and db then
        -- Surface the remaining seconds to the client for a useful UI hint.
        local rows, _ = db.call("aion_getuserinstance_20171122", blocking_cid)
        if rows then
            for _, r in ipairs(rows) do
                local iid = tonumber(r.instance_id or 0) or 0
                if iid == template_id then
                    local reentry = tonumber(r.reentrance_time or 0) or 0
                    local left = reentry - os.time()
                    if left > 0 then cooldown_remaining = left end
                    break
                end
            end
        end
    end
    log.warn("CM_INSTANCE_ENTER: reject template_id=" .. tostring(template_id)
        .. " reason=" .. tostring(reason))
    send_result(gw, code, 0, cooldown_remaining)
end)
