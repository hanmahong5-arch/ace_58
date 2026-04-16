-- scripts/lib/legion.lua
-- Legion (guild) state machine — Phase S-10.
--
-- A legion is the long-lived counterpart to a party: members persist across
-- logins, the roster survives hot-reloads, and the backing data lives in the
-- `guild` table via NCSoft stored procedures. This module mirrors the
-- group.lua API where it makes sense but differs in two key ways:
--
--   1. Persistence: create/disband/add-member hit aion_PutGuild_20100916,
--      aion_DeleteGuild, aion_SetGuildMember. The in-memory _legions cache is
--      a write-through view of the authoritative DB state.
--
--   2. Ranks: legions have 4 fixed ranks (0=BrigadeGeneral, 1=Centurion,
--      2=Legionary, 3=Deputy) with asymmetric privileges. The group only has
--      a single leader; the legion has a hierarchy.
--
-- Public API:
--   legion.create(founder_eid, name) -> ok, reason|legion_id
--     reasons: "in_legion" | "bad_name" | "no_kinah" | "db_failed"
--   legion.invite(inviter_eid, target_eid) -> ok, reason
--     reasons: "not_in_legion" | "no_rights" | "target_in_legion" | "full"
--   legion.accept(target_eid) -> ok, reason
--     reasons: "no_invite" | "expired" | "full" | "db_failed"
--   legion.leave(member_eid)  -> ok, reason
--     reasons: "not_in_legion" | "master_cannot_leave"
--   legion.disband(founder_eid) -> ok, reason
--     reasons: "not_in_legion" | "not_master"
--   legion.kick(kicker_eid, target_name) -> ok, reason
--     reasons: "not_in_legion" | "no_rights" | "target_not_member" | "cannot_kick_master"
--   legion.set_motd(setter_eid, motd) -> ok, reason
--     reasons: "not_in_legion" | "no_rights" | "too_long"
--   legion.get(member_eid) -> legion_table | nil
--   legion.member_gateways(member_eid) -> {gateway_seq_id, ...} | nil
--   legion.load_from_db(member_eid) -> legion_table | nil
--     Hydrates the in-memory cache from aion_GetCharGuildId + aion_GetGuild.
--     Called from cm_enter_world.lua so rejoining players see their legion.
--
-- A legion_table looks like:
--   {
--     id       = LegionID,
--     name     = "name",
--     master   = char_id (brigade general's char_id, DB-truth),
--     motd     = "string",
--     members  = { [char_id] = { char_id=N, rank=R, name="..." }, ... },
--   }
--
-- Note: members are keyed by char_id (persistent), NOT entity_id (session-
-- scoped). This lets us hold the roster even when some members are offline.

legion = {}

-- Rank constants (NCSoft AION convention).
legion.RANK_BRIGADE_GENERAL = 0
legion.RANK_CENTURION       = 1  -- can invite, kick
legion.RANK_LEGIONARY       = 2  -- rank-and-file
legion.RANK_DEPUTY          = 3  -- trial / newbie

-- Capacity and economy.
local MAX_MEMBERS       = 30
local CREATE_FEE_KINAH  = 100000
local MAX_MOTD_LEN      = 256
local INVITE_TTL_TICKS  = 20 * 60  -- 60 seconds at 20 Hz

-- NCSoft legion rights bitmask — copied verbatim from the C++ reference for
-- parity with live client expectations. 0 values are safe defaults; production
-- GMs can fine-tune via DB.
local DEFAULT_SUB_RIGHT   = 0
local DEFAULT_OFF_RIGHT   = 0
local DEFAULT_MEM_RIGHT   = 0
local DEFAULT_NEW_RIGHT   = 0

-- --------------------------------------------------------
-- In-memory state (write-through cache over the DB).
-- --------------------------------------------------------
local _legions         = {}  -- legion_id -> legion_table
local _member_legion   = {}  -- char_id   -> legion_id
local _pending_invites = {}  -- target_eid -> { inviter_eid, legion_id, created_tick }

-- --------------------------------------------------------
-- Internal helpers.
-- --------------------------------------------------------
local function char_id_of(eid)
    local cid = entity.get_stat(eid, "char_id")
    if not cid or cid <= 0 then return 0 end
    return math.floor(cid)
end

local function has_invite_right(rank)
    return rank == legion.RANK_BRIGADE_GENERAL or rank == legion.RANK_CENTURION
end

-- --------------------------------------------------------
-- Internal: send SM_LEGION_INFO (0xB6) to a single gateway.
-- Payload (LE, unverified):
--   int32       legion_id
--   utf16_null  legion_name
--   int32       master_char_id
--   utf16_null  motd
--   int32       member_count
--   repeat member_count times:
--     int32       char_id
--     byte        rank
--     byte        online (1=yes, 0=no)
--     utf16_null  char_name
-- --------------------------------------------------------
local function build_legion_info_packet(leg)
    local buf = bytes.new()
    buf:write_int32(leg.id)
    buf:write_string_utf16(leg.name or "")
    buf:write_int32(leg.master or 0)
    buf:write_string_utf16(leg.motd or "")

    -- Snapshot members into a deterministic order (master first, then by char_id).
    local ordered = {}
    for _, m in pairs(leg.members) do ordered[#ordered + 1] = m end
    table.sort(ordered, function(a, b)
        if a.char_id == leg.master then return true  end
        if b.char_id == leg.master then return false end
        return a.char_id < b.char_id
    end)

    buf:write_int32(#ordered)
    for _, m in ipairs(ordered) do
        buf:write_int32(m.char_id)
        buf:write_byte(m.rank or legion.RANK_LEGIONARY)
        buf:write_byte(m.online and 1 or 0)
        buf:write_string_utf16(m.name or "")
    end
    return buf:to_string()
end

-- --------------------------------------------------------
-- Internal: broadcast SM_LEGION_INFO to every online member.
-- --------------------------------------------------------
local function broadcast_legion_info(leg)
    -- Refresh online flags before snapshotting.
    for _, m in pairs(leg.members) do
        m.online = false
    end
    for _, eid in ipairs(entity.get_all_players()) do
        local cid = char_id_of(eid)
        if cid > 0 and leg.members[cid] then
            leg.members[cid].online = true
        end
    end

    local pkt = build_legion_info_packet(leg)
    for _, m in pairs(leg.members) do
        if m.online then
            for _, eid in ipairs(entity.get_all_players()) do
                if char_id_of(eid) == m.char_id then
                    local gw = entity.get_gateway_id(eid)
                    if gw then player.send_packet(gw, 0xB6, pkt) end
                    break
                end
            end
        end
    end
end

-- --------------------------------------------------------
-- legion.get(member_eid) -> legion_table | nil
-- --------------------------------------------------------
legion.get = function(member_eid)
    local cid = char_id_of(member_eid)
    if cid == 0 then return nil end
    local lid = _member_legion[cid]
    if not lid then return nil end
    return _legions[lid]
end

-- --------------------------------------------------------
-- legion.member_gateways(member_eid) -> {gateway_seq_id, ...} | nil
-- Returns gateways for every currently-online legion member.
-- --------------------------------------------------------
legion.member_gateways = function(member_eid)
    local leg = legion.get(member_eid)
    if not leg then return nil end
    local out = {}
    for _, eid in ipairs(entity.get_all_players()) do
        local cid = char_id_of(eid)
        if cid > 0 and leg.members[cid] then
            local gw = entity.get_gateway_id(eid)
            if gw then out[#out + 1] = gw end
        end
    end
    return out
end

-- --------------------------------------------------------
-- legion.create(founder_eid, name) -> ok, reason|legion_id
--
-- Creates a new legion with the founder as brigade general:
--   1. Validates name (non-empty, <= 24 chars) and rejects dupes via SP.
--   2. Charges CREATE_FEE_KINAH.
--   3. Calls aion_PutGuild_20100916 → returns new legion_id or negative error.
--   4. Calls aion_SetGuildMember to write guild_id into user_data.
--   5. Seeds the in-memory cache so SM_LEGION_INFO can fire immediately.
--
-- SP return values:
--    >0 = success, new legion id
--    -1 = duplicate name
--    -2 = forbidden word / banned name
-- --------------------------------------------------------
legion.create = function(founder_eid, name)
    if not name or #name == 0 or #name > 24 then
        return false, "bad_name"
    end
    local cid = char_id_of(founder_eid)
    if cid == 0 then return false, "not_in_legion" end
    if _member_legion[cid] then
        return false, "in_legion"
    end

    -- Resolve founder's race so SP race column matches.
    local race = math.floor(entity.get_stat(founder_eid, "race") or 0)
    local gw   = entity.get_gateway_id(founder_eid)
    if not gw then return false, "not_in_legion" end

    -- Charge fee BEFORE DB insert to avoid a free legion on DB failure.
    if not player.spend_kinah(gw, CREATE_FEE_KINAH) then
        return false, "no_kinah"
    end

    local rows, err = db.call("aion_PutGuild_20100916",
        name, cid, race,
        DEFAULT_SUB_RIGHT, DEFAULT_OFF_RIGHT,
        DEFAULT_MEM_RIGHT, DEFAULT_NEW_RIGHT)
    if err or not rows or #rows == 0 then
        -- Refund on DB failure.
        player.add_kinah(gw, CREATE_FEE_KINAH)
        log.warn("legion.create: SP failed err=" .. tostring(err))
        return false, "db_failed"
    end

    -- SP returns a single row with one integer column; walk values.
    local new_id = 0
    for _, v in pairs(rows[1]) do
        if type(v) == "number" then new_id = math.floor(v); break end
    end
    if new_id <= 0 then
        player.add_kinah(gw, CREATE_FEE_KINAH)
        return false, (new_id == -1) and "dup_name" or "bad_name"
    end

    -- Write guild_id into user_data.
    db.call("aion_SetGuildMember", new_id, cid)
    db.call("aion_SetGuildMemberRank", new_id, cid, legion.RANK_BRIGADE_GENERAL)

    -- Seed in-memory cache.
    local founder_name = player.get_name(gw) or ""
    local leg = {
        id      = new_id,
        name    = name,
        master  = cid,
        motd    = "",
        members = {
            [cid] = {
                char_id = cid,
                rank    = legion.RANK_BRIGADE_GENERAL,
                name    = founder_name,
                online  = true,
            },
        },
    }
    _legions[new_id]       = leg
    _member_legion[cid]    = new_id

    broadcast_legion_info(leg)
    log.info("legion.create: id=" .. new_id .. " name=" .. name
        .. " founder_cid=" .. cid)
    return true, new_id
end

-- --------------------------------------------------------
-- legion.invite(inviter_eid, target_eid) -> ok, reason
-- Store a pending invite on the target; accept() completes the join.
-- --------------------------------------------------------
legion.invite = function(inviter_eid, target_eid)
    local leg = legion.get(inviter_eid)
    if not leg then return false, "not_in_legion" end

    local inviter_cid = char_id_of(inviter_eid)
    local inv_member  = leg.members[inviter_cid]
    if not inv_member or not has_invite_right(inv_member.rank) then
        return false, "no_rights"
    end

    local target_cid = char_id_of(target_eid)
    if target_cid == 0 then return false, "target_not_online" end
    if _member_legion[target_cid] then
        return false, "target_in_legion"
    end

    local count = 0
    for _ in pairs(leg.members) do count = count + 1 end
    if count >= MAX_MEMBERS then return false, "full" end

    _pending_invites[target_eid] = {
        inviter_eid  = inviter_eid,
        legion_id    = leg.id,
        created_tick = current_tick or 0,
    }
    return true
end

-- --------------------------------------------------------
-- legion.accept(target_eid) -> ok, reason
-- --------------------------------------------------------
legion.accept = function(target_eid)
    local inv = _pending_invites[target_eid]
    if not inv then return false, "no_invite" end
    _pending_invites[target_eid] = nil

    if current_tick and (current_tick - (inv.created_tick or 0)) > INVITE_TTL_TICKS then
        return false, "expired"
    end

    local leg = _legions[inv.legion_id]
    if not leg then return false, "expired" end

    local count = 0
    for _ in pairs(leg.members) do count = count + 1 end
    if count >= MAX_MEMBERS then return false, "full" end

    local target_cid = char_id_of(target_eid)
    if target_cid == 0 then return false, "expired" end

    -- Persist: write guild_id + default rank (deputy) via SP.
    local _, err = db.call("aion_SetGuildMember", leg.id, target_cid)
    if err then
        log.warn("legion.accept: SetGuildMember failed err=" .. tostring(err))
        return false, "db_failed"
    end
    db.call("aion_SetGuildMemberRank", leg.id, target_cid, legion.RANK_DEPUTY)

    local gw   = entity.get_gateway_id(target_eid)
    local name = gw and player.get_name(gw) or ""
    leg.members[target_cid] = {
        char_id = target_cid,
        rank    = legion.RANK_DEPUTY,
        name    = name,
        online  = true,
    }
    _member_legion[target_cid] = leg.id

    broadcast_legion_info(leg)
    return true
end

-- --------------------------------------------------------
-- legion.leave(member_eid) -> ok, reason
-- The brigade general cannot leave; they must disband or transfer.
-- --------------------------------------------------------
legion.leave = function(member_eid)
    local leg = legion.get(member_eid)
    if not leg then return false, "not_in_legion" end
    local cid = char_id_of(member_eid)

    if leg.master == cid then
        return false, "master_cannot_leave"
    end

    leg.members[cid] = nil
    _member_legion[cid] = nil

    -- Persist: clear user_data.guild_id by passing 0.
    db.call("aion_SetGuildMember", 0, cid)

    broadcast_legion_info(leg)
    return true
end

-- --------------------------------------------------------
-- legion.kick(kicker_eid, target_name) -> ok, reason
-- Only the brigade general may kick. Resolves target by char_name.
-- --------------------------------------------------------
legion.kick = function(kicker_eid, target_name)
    local leg = legion.get(kicker_eid)
    if not leg then return false, "not_in_legion" end

    local kicker_cid = char_id_of(kicker_eid)
    if leg.master ~= kicker_cid then
        return false, "no_rights"
    end

    -- Find target by name in the legion roster.
    local target_cid
    for cid, m in pairs(leg.members) do
        if m.name == target_name then target_cid = cid; break end
    end
    if not target_cid then return false, "target_not_member" end
    if target_cid == leg.master then return false, "cannot_kick_master" end

    leg.members[target_cid] = nil
    _member_legion[target_cid] = nil
    db.call("aion_SetGuildMember", 0, target_cid)

    broadcast_legion_info(leg)
    return true
end

-- --------------------------------------------------------
-- legion.disband(founder_eid) -> ok, reason
-- --------------------------------------------------------
legion.disband = function(founder_eid)
    local leg = legion.get(founder_eid)
    if not leg then return false, "not_in_legion" end
    local cid = char_id_of(founder_eid)
    if leg.master ~= cid then return false, "not_master" end

    -- Clear all member links in DB.
    for member_cid, _ in pairs(leg.members) do
        db.call("aion_SetGuildMember", 0, member_cid)
        _member_legion[member_cid] = nil
    end
    db.call("aion_DeleteGuildMemberAll", leg.id)
    db.call("aion_DeleteGuild", leg.id)

    _legions[leg.id] = nil
    return true
end

-- --------------------------------------------------------
-- legion.set_motd(setter_eid, motd) -> ok, reason
-- --------------------------------------------------------
legion.set_motd = function(setter_eid, motd)
    local leg = legion.get(setter_eid)
    if not leg then return false, "not_in_legion" end
    local cid = char_id_of(setter_eid)
    local me  = leg.members[cid]
    if not me or not has_invite_right(me.rank) then
        return false, "no_rights"
    end
    if motd and #motd > MAX_MOTD_LEN then
        return false, "too_long"
    end
    leg.motd = motd or ""
    -- notice1 = motd for now; SP signature allows 7 notice slots.
    db.call("aion_SetGuildNotices", leg.id,
        leg.motd, "", "", "", "", "", "")
    broadcast_legion_info(leg)
    return true
end

-- --------------------------------------------------------
-- legion.load_from_db(member_eid) -> legion_table | nil
-- Called from cm_enter_world after DB returns character row: checks if this
-- char has a guild_id and hydrates the cache if not yet loaded. Idempotent.
-- --------------------------------------------------------
legion.load_from_db = function(member_eid)
    local cid = char_id_of(member_eid)
    if cid == 0 then return nil end

    -- Fast path: already cached.
    if _member_legion[cid] and _legions[_member_legion[cid]] then
        return _legions[_member_legion[cid]]
    end

    -- Resolve guild_id from user_data.
    local rows = db.call("aion_GetCharGuildId", cid)
    if not rows or #rows == 0 then return nil end
    local guild_id = 0
    for _, v in pairs(rows[1]) do
        if type(v) == "number" then guild_id = math.floor(v); break end
    end
    if guild_id <= 0 then return nil end

    -- Fast path: legion already hydrated by another member.
    if _legions[guild_id] then
        _member_legion[cid] = guild_id
        local gw = entity.get_gateway_id(member_eid)
        local nm = gw and player.get_name(gw) or ""
        _legions[guild_id].members[cid] = {
            char_id = cid, rank = legion.RANK_LEGIONARY, name = nm, online = true,
        }
        return _legions[guild_id]
    end

    -- Cold load: fetch legion header via aion_GetGuild_20150508.
    local grows = db.call("aion_GetGuild_20150508", guild_id)
    if not grows or #grows == 0 then return nil end
    local g = grows[1]
    local master = 0
    if type(g.master_id) == "number" then master = math.floor(g.master_id) end

    local name = ""
    if type(g.name) == "string" then name = g.name end

    local gw = entity.get_gateway_id(member_eid)
    local nm = gw and player.get_name(gw) or ""
    local leg = {
        id      = guild_id,
        name    = name,
        master  = master,
        motd    = "",
        members = {
            [cid] = {
                char_id = cid,
                rank    = (cid == master) and legion.RANK_BRIGADE_GENERAL
                                          or legion.RANK_LEGIONARY,
                name    = nm,
                online  = true,
            },
        },
    }
    _legions[guild_id]   = leg
    _member_legion[cid]  = guild_id
    return leg
end

-- --------------------------------------------------------
-- Test hook: clear all state (used by luahost unit tests).
-- --------------------------------------------------------
legion._reset = function()
    _legions         = {}
    _member_legion   = {}
    _pending_invites = {}
end

-- --------------------------------------------------------
-- Test hook (Phase S-17): seed a pending invite without running the full
-- legion.invite flow. Used by unit tests that exercise _clear_invite /
-- on_legion_invite_expire without wiring a DB mock.
-- --------------------------------------------------------
legion._seed_invite = function(target_eid, inviter_eid, legion_id)
    _pending_invites[target_eid] = {
        inviter_eid  = inviter_eid,
        legion_id    = legion_id,
        created_tick = current_tick or 0,
    }
end

-- --------------------------------------------------------
-- Phase S-17: clear a pending invite entry if it still matches the call
-- args. Used by scripts/events/on_legion_invite_expire.lua (dispatched from
-- the river LegionInviteExpireWorker). Safe to call on a missing or
-- already-accepted invite — the function is a no-op in both cases.
-- --------------------------------------------------------
legion._clear_invite = function(target_eid, legion_id)
    local inv = _pending_invites[target_eid]
    if not inv then return false end
    if legion_id and inv.legion_id ~= legion_id then
        return false
    end
    _pending_invites[target_eid] = nil
    return true
end
