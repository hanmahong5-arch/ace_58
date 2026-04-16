-- scripts/handlers/cm_warehouse_list.lua
-- CM_WAREHOUSE_LIST (0xC5): client requests its account warehouse contents.
--
-- Payload: empty.
-- Server responds with SM_WAREHOUSE_LIST (0xC8):
--   int32 count
--   for each row: int32 item_id, int32 item_count, int32 slot

register_handler(0xC5, function(ctx, payload)
    if not warehouse then
        log.warn("CM_WAREHOUSE_LIST: warehouse lib not loaded")
        return
    end

    local rows = warehouse.list(ctx.entity_id)
    local count = (rows and #rows) or 0

    local buf = bytes.new()
    buf:write_int32(count)
    for _, row in ipairs(rows or {}) do
        local iid  = tonumber(row.item_id    or 0) or 0
        local icnt = tonumber(row.item_count or row.count or 1) or 1
        local slot = tonumber(row.slot       or row.equip_slot_position or 0) or 0
        buf:write_int32(iid)
        buf:write_int32(icnt)
        buf:write_int32(slot)
    end

    player.send_packet(ctx.gateway_seq_id, 0xC8, buf:to_string())
    log.info("CM_WAREHOUSE_LIST: entity=" .. tostring(ctx.entity_id)
        .. " count=" .. tostring(count))
end)
