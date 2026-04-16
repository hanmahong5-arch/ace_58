-- scripts/handlers/cm_warehouse_withdraw.lua
-- CM_WAREHOUSE_WITHDRAW (0xC7): client moves an item from warehouse → inventory.
--
-- Payload (LE):
--   int32 item_id
--   int32 count

register_handler(0xC7, function(ctx, payload)
    if not warehouse then
        log.warn("CM_WAREHOUSE_WITHDRAW: warehouse lib not loaded")
        return
    end
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local item_id = payload:read_int32()
    local count   = payload:read_int32()

    local ok, reason = warehouse.withdraw(ctx.entity_id, item_id, count)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Warehouse withdraw failed: " .. tostring(reason))
        end
        log.info("CM_WAREHOUSE_WITHDRAW: rejected entity=" .. tostring(ctx.entity_id)
            .. " item_id=" .. tostring(item_id)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_WAREHOUSE_WITHDRAW: ok entity=" .. tostring(ctx.entity_id)
        .. " item_id=" .. tostring(item_id)
        .. " count=" .. tostring(count))
end)
