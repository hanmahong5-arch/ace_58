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
    -- Round 13: count 仍在 wire 上由 client 发送（保留 byte 消费），但 lib 已用
    -- aion_setitemwarehouse_20111227 行级 transfer，不需要 count；忽略保留以待
    -- 客户端 split-stack 流程到位后再用。
    local _count  = payload:read_int32()

    local ok, reason = warehouse.deposit(ctx.entity_id, item_id)
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
        .. " item_id=" .. tostring(item_id))
end)
