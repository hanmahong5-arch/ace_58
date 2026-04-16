-- scripts/handlers/cm_warehouse_deposit.lua
-- CM_WAREHOUSE_DEPOSIT (0xC6): client moves an item from inventory → warehouse.
--
-- Payload (LE):
--   int32 item_id
--   int32 count
--
-- Requires an active warehouse session opened via a Warehouse Keeper dialog;
-- warehouse.deposit itself enforces range and kinah fee.

register_handler(0xC6, function(ctx, payload)
    if not warehouse then
        log.warn("CM_WAREHOUSE_DEPOSIT: warehouse lib not loaded")
        return
    end
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    local item_id = payload:read_int32()
    local count   = payload:read_int32()

    local ok, reason = warehouse.deposit(ctx.entity_id, item_id, count)
    if not ok then
        if chat and chat.send_system then
            chat.send_system(ctx.gateway_seq_id,
                "Warehouse deposit failed: " .. tostring(reason))
        end
        log.info("CM_WAREHOUSE_DEPOSIT: rejected entity=" .. tostring(ctx.entity_id)
            .. " item_id=" .. tostring(item_id)
            .. " reason=" .. tostring(reason))
        return
    end

    log.info("CM_WAREHOUSE_DEPOSIT: ok entity=" .. tostring(ctx.entity_id)
        .. " item_id=" .. tostring(item_id)
        .. " count=" .. tostring(count))
end)
