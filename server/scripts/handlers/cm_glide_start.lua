-- scripts/handlers/cm_glide_start.lua
-- CM_GLIDE_START (0x72): player began gliding (jump + hold glide key).
--
-- Payload: empty. Only valid when currently on GROUND.

register_handler(0x72, function(ctx, payload)
    if not flight then return end
    flight.glide_start(ctx.entity_id)
end)
