-- scripts/lib/group.lua
-- Party (group) state machine.
--
-- State is kept in Lua tables and reset on hot-reload — acceptable for
-- development. Production persistence would require moving state to Redis.
--
-- Public API:
--   group.invite(leader_eid, target_eid) -> ok, reason
--   group.accept(target_eid) -> ok, reason   (target must have a pending invite)
--   group.leave(member_eid)  -> ok, reason
--   group.disband(leader_eid) -> ok, reason
--   group.get(member_eid) -> group_table | nil
--   group.members(member_eid) -> {entity_id, ...} | nil
--   group.member_gateways(member_eid) -> {gateway_seq_id, ...} | nil
--
-- A group_table looks like:
--   { id=GroupID, leader=Entity, members={Entity,...}, created_tick=N }

group = {}

local MAX_MEMBERS = 6

-- GroupID is an incrementing counter; starts at 1 so 0 means "no group".
local _next_group_id = 1

local _groups       = {}  -- GroupID -> group_table
local _member_group = {}  -- Entity -> GroupID
local _pending      = {}  -- target_eid -> {leader_eid, group_id, created_tick}

-- --------------------------------------------------------
-- Internal: allocate a fresh group wrapping the leader.
-- --------------------------------------------------------
local function new_group(leader_eid)
    local g = {
        id           = _next_group_id,
        leader       = leader_eid,
        members      = { leader_eid },
        created_tick = current_tick or 0,
    }
    _groups[_next_group_id] = g
    _member_group[leader_eid] = _next_group_id
    _next_group_id = _next_group_id + 1
    return g
end

-- --------------------------------------------------------
-- group.get(eid) -> group_table | nil
-- --------------------------------------------------------
group.get = function(eid)
    local gid = _member_group[eid]
    if not gid then return nil end
    return _groups[gid]
end

-- --------------------------------------------------------
-- group.members(eid) -> {Entity, ...} | nil
-- Returns a copy of the member list so callers can iterate safely.
-- --------------------------------------------------------
group.members = function(eid)
    local g = group.get(eid)
    if not g then return nil end
    local copy = {}
    for i, m in ipairs(g.members) do copy[i] = m end
    return copy
end

-- --------------------------------------------------------
-- group.member_gateways(eid) -> {gateway_seq_id, ...} | nil
-- Resolves each member's live gateway session ID (skips offline members).
-- Used by chat.broadcast_group and SM_GROUP_* broadcasts.
-- --------------------------------------------------------
group.member_gateways = function(eid)
    local g = group.get(eid)
    if not g then return nil end
    local out = {}
    for _, m in ipairs(g.members) do
        local gw = entity.get_gateway_id(m)
        if gw then out[#out + 1] = gw end
    end
    return out
end

-- --------------------------------------------------------
-- Internal: send SM_GROUP_INFO (0x63) to every member with the current roster.
-- Payload (LE, unverified):
--   int32  group_id
--   int32  leader_entity_id
--   int32  member_count
--   repeat member_count times:
--     int32         member_entity_id
--     utf16_null    member_name
--     int32         hp
--     int32         max_hp
-- --------------------------------------------------------
local function broadcast_group_info(g)
    local buf = bytes.new()
    buf:write_int32(g.id)
    buf:write_int32(g.leader)
    buf:write_int32(#g.members)
    for _, m in ipairs(g.members) do
        buf:write_int32(m)
        local gw = entity.get_gateway_id(m)
        local name = gw and player.get_name(gw) or ""
        buf:write_string_utf16(name)
        buf:write_int32(math.floor(entity.get_stat(m, "hp")))
        buf:write_int32(math.floor(entity.get_stat(m, "max_hp")))
    end
    local pkt = buf:to_string()

    for _, m in ipairs(g.members) do
        local gw = entity.get_gateway_id(m)
        if gw then player.send_packet(gw, 0x63, pkt) end
    end
end

-- --------------------------------------------------------
-- group.invite(leader_eid, target_eid) -> ok, reason
--   "already_in_group" — target already belongs to any group
--   "self"             — target == leader
--   "full"             — leader's group is at MAX_MEMBERS
-- --------------------------------------------------------
group.invite = function(leader_eid, target_eid)
    if leader_eid == target_eid then
        return false, "self"
    end
    if _member_group[target_eid] then
        return false, "already_in_group"
    end

    local g = group.get(leader_eid)
    if g and #g.members >= MAX_MEMBERS then
        return false, "full"
    end

    -- Create-on-invite: leader auto-forms a party of one on first invite.
    if not g then
        g = new_group(leader_eid)
    end

    _pending[target_eid] = {
        leader_eid   = leader_eid,
        group_id     = g.id,
        created_tick = current_tick or 0,
    }
    return true
end

-- --------------------------------------------------------
-- group.accept(target_eid) -> ok, reason
--   "no_invite" — no pending invite for this entity
--   "expired"   — group no longer exists (leader left/disbanded)
--   "full"      — group filled up while invite was pending
-- --------------------------------------------------------
group.accept = function(target_eid)
    local inv = _pending[target_eid]
    if not inv then return false, "no_invite" end
    _pending[target_eid] = nil

    local g = _groups[inv.group_id]
    if not g then return false, "expired" end
    if #g.members >= MAX_MEMBERS then return false, "full" end

    g.members[#g.members + 1] = target_eid
    _member_group[target_eid] = g.id

    broadcast_group_info(g)
    return true
end

-- --------------------------------------------------------
-- group.leave(member_eid) -> ok, reason
-- If the leaver was the leader, the next-earliest member is promoted.
-- If fewer than 2 members remain, the group is disbanded.
-- --------------------------------------------------------
group.leave = function(member_eid)
    local g = group.get(member_eid)
    if not g then return false, "not_in_group" end

    -- Remove member from roster.
    for i, m in ipairs(g.members) do
        if m == member_eid then
            table.remove(g.members, i)
            break
        end
    end
    _member_group[member_eid] = nil

    -- Disband if the party is now a solo shell.
    if #g.members < 2 then
        if #g.members == 1 then
            _member_group[g.members[1]] = nil
        end
        _groups[g.id] = nil
        return true
    end

    -- Promote a new leader if needed.
    if g.leader == member_eid then
        g.leader = g.members[1]
    end

    broadcast_group_info(g)
    return true
end

-- --------------------------------------------------------
-- group.disband(leader_eid) -> ok, reason
-- Non-leaders get "not_leader".
-- --------------------------------------------------------
group.disband = function(leader_eid)
    local g = group.get(leader_eid)
    if not g then return false, "not_in_group" end
    if g.leader ~= leader_eid then return false, "not_leader" end

    for _, m in ipairs(g.members) do
        _member_group[m] = nil
    end
    _groups[g.id] = nil
    return true
end
