-- scripts/lib/warehouse.lua
-- Phase S-15: account warehouse (bank) state machine.
--
-- Round 13 rename — real NCSoft SP wiring:
--   list     -> aion_getitemlist_20120102      (00037)  args: char_id, warehouse
--   deposit  -> aion_setitemwarehouse_20111227 (00134)  args: item_id, warehouse=2, owner_id
--   withdraw -> aion_setitemwarehouse_20111227 (00134)  args: item_id, warehouse=0, owner_id
--
-- 关键认知（vs 旧 placeholder 设计）：
--   NCSoft 没有"独立 warehouse 表"。所有玩家物品都在 user_item，靠 warehouse 列
--   做分区。"deposit/withdraw" = 改 user_item.warehouse 值（0 ↔ 2）。这对 stack
--   行为有副作用：transfer 是按行（user_item.id）粒度，整 stack 进出。stack 拆分
--   由客户端在 transfer 前先发 CM_SPLIT_ITEM（暂未实现，Round 14+）。
--
-- Contract:
--   warehouse.MAX_SLOTS / FEE_PER_TX / NPC_RANGE   -- constants
--   warehouse.list(reader_eid) -> array of user_item rows (10 cols)
--   warehouse.deposit(eid, item_id) -> ok, reason
--     reasons: "bad_id" | "no_session" | "no_kinah" | "sp_failed"
--   warehouse.withdraw(eid, item_id) -> ok, reason
--     reasons: "bad_id" | "no_session" | "no_kinah" | "sp_failed"
--   warehouse.open_session(eid, npc_eid)             -- session marker for range check
--   warehouse.close_session(eid)
--   warehouse.has_session(eid) -> bool
--
-- Design notes:
--   - Session table `_active_sessions` is keyed by player entity_id; matches
--     S-8 shop's `_active_shops` pattern. Cleared on hot-reload and on
--     player despawn (acceptable given the 15 m enforcement).
--   - 签名变更：从 (eid, item_id, count) → (eid, item_id)。count 不需要因为
--     SetItemWarehouse 是按 user_item.id 行级 transfer，不涉及 amount 调整。
--     旧调用方需对应修订 — 当前 cm_warehouse_deposit/withdraw 包装层已检查。

warehouse = {}

warehouse.MAX_SLOTS  = 104       -- AION 5.8 standard account warehouse capacity
warehouse.FEE_PER_TX = 10        -- kinah per deposit OR withdraw
warehouse.NPC_RANGE  = 15.0      -- metres from the Warehouse Keeper NPC

-- NCSoft warehouse partition codes (与 00037 注释 + 00134 SP 一致)。
warehouse.PART_INVENTORY = 0     -- cube / 主背包
warehouse.PART_CHAR      = 1     -- 角色专属仓库
warehouse.PART_ACCOUNT   = 2     -- 账号共享仓库（本 lib 默认操作对象）

local _active_sessions = {}      -- player_eid → npc_eid

-- --- Session helpers -----------------------------------------------------

warehouse.open_session = function(eid, npc_eid)
    _active_sessions[eid] = npc_eid
end

warehouse.close_session = function(eid)
    _active_sessions[eid] = nil
end

warehouse.has_session = function(eid)
    return _active_sessions[eid] ~= nil
end

-- _in_range(eid) returns true when the player still stands within
-- NPC_RANGE metres of the NPC they opened the dialog with. Used to reject
-- requests after the player walks away.
local function _in_range(eid)
    local npc_eid = _active_sessions[eid]
    if not npc_eid then return false end
    local nearby = entity.get_nearby(eid, warehouse.NPC_RANGE)
    for _, nid in ipairs(nearby) do
        if nid == npc_eid then return true end
    end
    return false
end

local function _char_id(eid)
    return math.floor(entity.get_stat(eid, "char_id") or 0)
end

-- --- warehouse.list ------------------------------------------------------

-- Returns the array of warehouse rows for the player. Empty table on SP
-- failure or when the player has no char_id (non-player entity).
-- aion_getitemlist_20120102 (00037) 按 char_id × warehouse 取行，过滤 export_id=0。
warehouse.list = function(reader_eid)
    local cid = _char_id(reader_eid)
    if cid == 0 or not db then
        return {}
    end
    local rows, err = db.call("aion_getitemlist_20120102", cid, warehouse.PART_ACCOUNT)
    if err or not rows then
        if err then log.warn("warehouse.list: SP err=" .. tostring(err)) end
        return {}
    end
    return rows
end

-- --- warehouse.deposit ---------------------------------------------------

-- 把 user_item.id 整行 transfer 进 ACCOUNT 仓库（warehouse 列从 0 → 2）。
-- count 不再需要：transfer 是行级；如需拆分先走客户端 split。
warehouse.deposit = function(eid, item_id)
    item_id = tonumber(item_id) or 0
    if item_id <= 0 then
        return false, "bad_id"
    end
    if not warehouse.has_session(eid) or not _in_range(eid) then
        return false, "no_session"
    end

    local gw = entity.get_gateway_id(eid)
    if not gw then return false, "no_session" end

    if not player.spend_kinah(gw, warehouse.FEE_PER_TX) then
        return false, "no_kinah"
    end

    local cid = _char_id(eid)
    if cid == 0 or not db then
        -- DB unavailable: refund and surface as sp_failed.
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        return false, "sp_failed"
    end

    local _, err = db.call("aion_setitemwarehouse_20111227",
        item_id, warehouse.PART_ACCOUNT, cid)
    if err then
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        log.warn("warehouse.deposit: SP err=" .. tostring(err))
        return false, "sp_failed"
    end

    log.info("warehouse.deposit: char_id=" .. tostring(cid)
        .. " item_id=" .. tostring(item_id))
    return true, nil
end

-- --- warehouse.withdraw --------------------------------------------------

-- 把 user_item.id 从 ACCOUNT 仓库 transfer 回 INVENTORY（warehouse 列 2 → 0）。
warehouse.withdraw = function(eid, item_id)
    item_id = tonumber(item_id) or 0
    if item_id <= 0 then
        return false, "bad_id"
    end
    if not warehouse.has_session(eid) or not _in_range(eid) then
        return false, "no_session"
    end

    local gw = entity.get_gateway_id(eid)
    if not gw then return false, "no_session" end

    if not player.spend_kinah(gw, warehouse.FEE_PER_TX) then
        return false, "no_kinah"
    end

    local cid = _char_id(eid)
    if cid == 0 or not db then
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        return false, "sp_failed"
    end

    local _, err = db.call("aion_setitemwarehouse_20111227",
        item_id, warehouse.PART_INVENTORY, cid)
    if err then
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        log.warn("warehouse.withdraw: SP err=" .. tostring(err))
        return false, "sp_failed"
    end

    log.info("warehouse.withdraw: char_id=" .. tostring(cid)
        .. " item_id=" .. tostring(item_id))
    return true, nil
end
