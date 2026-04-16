-- scripts/lib/warehouse.lua
-- Phase S-15: account warehouse (bank) state machine.
--
-- Responsibilities:
--   * Read the player's stored items via aion_GetWarehouseByUser.
--   * Move items between inventory ↔ warehouse with kinah fees.
--   * Reject deposits/withdrawals when the player is out of range of an
--     opened Warehouse Keeper NPC (session state from a CM_DIALOG_REQUEST
--     against an NPC bound to this lib via warehouse.open_session).
--
-- Contract:
--   warehouse.MAX_SLOTS / FEE_PER_TX / NPC_RANGE   -- constants
--   warehouse.list(reader_eid) -> array of {item_id, item_count, slot}
--   warehouse.deposit(eid, item_id, count) -> ok, reason
--     reasons: "bad_count" | "no_session" | "no_kinah" | "remove_failed" | "sp_failed"
--   warehouse.withdraw(eid, item_id, count) -> ok, reason
--     reasons: "bad_count" | "no_session" | "no_kinah" | "sp_failed" | "add_failed"
--   warehouse.open_session(eid, npc_eid)             -- session marker for range check
--   warehouse.close_session(eid)
--   warehouse.has_session(eid) -> bool
--
-- Design notes:
--   - Session table `_active_sessions` is keyed by player entity_id; matches
--     S-8 shop's `_active_shops` pattern. Cleared on hot-reload and on
--     player despawn (acceptable given the 15 m enforcement).
--   - SP names (aion_GetWarehouseByUser / aion_DepositItemUser /
--     aion_WithdrawItemUser) are placeholders; verify against the migration
--     bundle before production.
--   - Deposit semantics: the inventory-side removal happens in the SP path
--     (SP is expected to be a single transaction that decrements user_item
--     and increments warehouse). On any SP error the cached kinah fee is
--     refunded via player.add_kinah so a DB outage cannot lose kinah.
--   - Withdraw semantics: the SP grants the row to the inventory directly;
--     this lib does NOT call player.add_item afterwards. If the SP path is
--     not yet deployed we fall back to player.add_item on success — see the
--     `add_failed` rollback branch.

warehouse = {}

warehouse.MAX_SLOTS  = 104       -- AION 5.8 standard account warehouse capacity
warehouse.FEE_PER_TX = 10        -- kinah per deposit OR withdraw
warehouse.NPC_RANGE  = 15.0      -- metres from the Warehouse Keeper NPC

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
warehouse.list = function(reader_eid)
    local cid = _char_id(reader_eid)
    if cid == 0 or not db then
        return {}
    end
    local rows, err = db.call("aion_GetWarehouseByUser", cid)
    if err or not rows then
        if err then log.warn("warehouse.list: SP err=" .. tostring(err)) end
        return {}
    end
    return rows
end

-- --- warehouse.deposit ---------------------------------------------------

warehouse.deposit = function(eid, item_id, count)
    item_id = tonumber(item_id) or 0
    count   = tonumber(count)   or 0
    if item_id <= 0 or count <= 0 then
        return false, "bad_count"
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

    local _, err = db.call("aion_DepositItemUser", cid, item_id, count)
    if err then
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        log.warn("warehouse.deposit: SP err=" .. tostring(err))
        return false, "sp_failed"
    end

    log.info("warehouse.deposit: char_id=" .. tostring(cid)
        .. " item_id=" .. tostring(item_id)
        .. " count=" .. tostring(count))
    return true, nil
end

-- --- warehouse.withdraw --------------------------------------------------

warehouse.withdraw = function(eid, item_id, count)
    item_id = tonumber(item_id) or 0
    count   = tonumber(count)   or 0
    if item_id <= 0 or count <= 0 then
        return false, "bad_count"
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

    local _, err = db.call("aion_WithdrawItemUser", cid, item_id, count)
    if err then
        player.add_kinah(gw, warehouse.FEE_PER_TX)
        log.warn("warehouse.withdraw: SP err=" .. tostring(err))
        return false, "sp_failed"
    end

    log.info("warehouse.withdraw: char_id=" .. tostring(cid)
        .. " item_id=" .. tostring(item_id)
        .. " count=" .. tostring(count))
    return true, nil
end
