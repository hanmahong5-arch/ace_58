-- scripts/handlers/cm_glide_end.lua
-- CM_GLIDE_END (0x73): player stopped gliding (lands or transitions to FLY).
--
-- Payload: empty.

register_handler(0x73, function(ctx, payload)
    if not flight then return end
    flight.glide_end(ctx.entity_id)
end)
