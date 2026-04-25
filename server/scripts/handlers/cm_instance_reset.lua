-- scripts/handlers/cm_instance_reset.lua
-- CM_INSTANCE_RESET (0xD4): player pays kinah to clear a template's cooldown.
--
-- Payload (LE):
--   int32 template_id
--
-- Response: a refreshed SM_INSTANCE_COOLDOWNS (0xD5) is pushed on success;
-- on failure a SM_CHAT system-channel line explains why.

register_handler(0xD4, function(ctx, payload)
    local template_id = payload:read_int32()
    local ok, reason = instance.reset(ctx.entity_id, template_id)
    if ok then
        log.info("CM_INSTANCE_RESET: cleared template_id=" .. tostring(template_id))
        return
    end
    local gw = ctx.gateway_seq_id
    local msg
    if     reason == "no_kinah"         then msg = "Insufficient kinah for reset."
    elseif reason == "currently_in_run" then msg = "You are still inside this instance."
    elseif reason == "template_unknown" then msg = "Unknown instance."
    else                                     msg = "Reset failed: " .. tostring(reason) end
    if chat and chat.send_system then
        chat.send_system(gw, msg)
    end
end)
