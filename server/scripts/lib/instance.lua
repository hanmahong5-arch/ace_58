-- scripts/lib/instance.lua
-- Phase S-19: Instance / dungeon state machine.
--
-- Design source of truth: C:\Users\Administrator\.claude\plans\proud-questing-raven.md
--
-- Responsibilities:
--   * Register per-dungeon templates (world_id, spawn, level range, rewards)
--   * Create a run (two-phase commit over per-member SP cooldown writes)
--   * Persist cooldown via aion_setuserinstance_20171122
--   * Teleport the party into the instance WorldID + spawn point
--   * Spawn the boss NPC (with stat instance_run_id for future world filtering)
--   * Broadcast SM_INSTANCE_STATE / SM_INSTANCE_MEMBER_JOIN / _LEAVE / _REWARD
--   * Survive full wipes: run is NOT disposed on #members==0 (black-cooldown fix)
--   * Allow crash-recovery re-entry: cooldown-row but no in-memory run → rejoin
--   * Reject stale jobq expiries via created_at_unix validation
--   * Hook into group.kick / group.leave so ejected members are force-left
--
-- Public surface:
--   instance.register(template_table)                       -- at script load
--   instance.create(leader_eid, template_id) -> run_id|nil, reason
--   instance.leave(eid)                                     -- explicit leave
--   instance.rejoin(eid, template_id) -> ok, reason         -- after disconnect
--   instance.reset(eid, template_id)  -> ok, reason         -- pay kinah, clear cd
--   instance.on_boss_kill(victim_eid, killer_eid) -> bool   -- from on_kill.lua
--   instance.on_expire(run_id, created_at_unix)             -- from on_instance_expire
--   instance.get(run_id) -> inst | nil
--   instance.get_by_eid(eid) -> inst | nil
--   instance.member_gateways(inst) -> {gw, gw, ...}
--   instance.has_char_run(char_id) -> run_id | nil          -- for crash-recovery guard
--   instance.get_template(template_id) -> template | nil
--
-- States:
--   LOBBY   = 0  -- allocated but boss not yet spawned
--   ACTIVE  = 1  -- boss up, members inside
--   CLEARED = 2  -- boss dead, rewards dispatched; run alive until expiry
--   EXPIRED = 3  -- validity_hours passed or explicit dispose; GC'd shortly
--
-- ECS stat contract on members (and boss NPC):
--   "instance_run_id"  numeric; 0 = open world, otherwise the active run_id
--
-- NOTE: all SM_INSTANCE_* wire formats are best-effort pending packet capture
-- against the live 5.8 client; adjust after hands-on verification.

instance = {}

instance.STATE_LOBBY   = 0
instance.STATE_ACTIVE  = 1
instance.STATE_CLEARED = 2
instance.STATE_EXPIRED = 3

-- Opcode constants — duplicated from Go aionproto/opcodes.go so Lua is
-- self-contained (the Go bridge does not auto-export opcode tables).
local OP_SM_INSTANCE_ENTER_RESULT = 0xD0
local OP_SM_INSTANCE_STATE        = 0xD2
local OP_SM_INSTANCE_REWARD       = 0xD3
local OP_SM_INSTANCE_COOLDOWNS    = 0xD5
local OP_SM_INSTANCE_MEMBER_JOIN  = 0xD6
local OP_SM_INSTANCE_MEMBER_LEAVE = 0xD7

-- Result codes for SM_INSTANCE_ENTER_RESULT (mirrors the plan).
instance.R_OK                   = 0
instance.R_COOLDOWN             = 1
instance.R_BAD_LEVEL            = 2
instance.R_BAD_GROUP_SIZE       = 3
instance.R_NOT_LEADER           = 4
instance.R_ALREADY_IN_INSTANCE  = 5
instance.R_DB_ERROR             = 6
instance.R_TEMPLATE_UNKNOWN     = 7

-- State tables.
local _instances       = {}   -- run_id   → instance_table
local _member_instance = {}   -- eid      → run_id (live presence)
local _char_run        = {}   -- char_id  → run_id (persistent membership)
local _templates       = {}   -- template_id → template_table
local _next_run_id     = 1

-- ----------------------------------------------------------------------------
-- Utility helpers.
-- ----------------------------------------------------------------------------

local function _char_id(eid)
    return math.floor(entity.get_stat(eid, "char_id") or 0)
end

local function _level(eid)
    return math.floor(entity.get_stat(eid, "level") or 1)
end

local function _alive(eid)
    return (tonumber(entity.get_stat(eid, "dead") or 0) or 0) == 0
end

local function _server_id()
    -- MVP: single shard. The value is irrelevant for SP-side dedup but must be
    -- consistent across reads/writes so cooldown lookups match.
    return 1
end

-- ----------------------------------------------------------------------------
-- instance.register — templates are registered at script-load by files
-- under scripts/instances/.
-- ----------------------------------------------------------------------------

instance.register = function(t)
    if type(t) ~= "table" or not t.template_id then
        log.warn("instance.register: invalid template")
        return
    end
    local tid = math.floor(t.template_id)
    if _templates[tid] then
        log.warn("instance.register: duplicate template_id=" .. tostring(tid))
        return
    end
    -- Defaults so templates can stay terse.
    t.min_members     = t.min_members     or 1
    t.max_members     = t.max_members     or 6
    t.reentrance_sec  = t.reentrance_sec  or 21600   -- 6h default
    t.validity_hours  = t.validity_hours  or 2
    t.reset_fee_kinah = t.reset_fee_kinah or 10000
    t.rewards         = t.rewards         or { kinah = 0, items = {} }
    _templates[tid] = t
    log.info("instance.register: loaded template_id=" .. tostring(tid)
        .. " name=" .. tostring(t.display_name or "?"))
end

instance.get_template = function(template_id)
    return _templates[math.floor(tonumber(template_id) or 0)]
end

-- ----------------------------------------------------------------------------
-- Broadcast helpers — all in-instance sends go through explicit member lists
-- (NOT get_nearby_players) to avoid cross-world packet leakage. See plan
-- §"Cross-instance broadcast safety".
-- ----------------------------------------------------------------------------

instance.member_gateways = function(inst)
    if not inst then return {} end
    local out = {}
    for _, m in ipairs(inst.members) do
        local gw = entity.get_gateway_id(m)
        if gw then out[#out + 1] = gw end
    end
    return out
end

local function _bcast_state(inst)
    local buf = bytes.new()
    buf:write_int64(inst.id)
    buf:write_byte(inst.state)
    local pkt = buf:to_string()
    for _, gw in ipairs(instance.member_gateways(inst)) do
        player.send_packet(gw, OP_SM_INSTANCE_STATE, pkt)
    end
end

local function _bcast_member_join(inst, joiner_eid)
    local name = ""
    local gw = entity.get_gateway_id(joiner_eid)
    if gw then name = player.get_name(gw) or "" end
    local buf = bytes.new()
    buf:write_int64(inst.id)
    buf:write_int32(joiner_eid)
    buf:write_string_utf16(name)
    local pkt = buf:to_string()
    for _, ogw in ipairs(instance.member_gateways(inst)) do
        player.send_packet(ogw, OP_SM_INSTANCE_MEMBER_JOIN, pkt)
    end
end

local function _bcast_member_leave(inst, leaver_eid)
    local buf = bytes.new()
    buf:write_int64(inst.id)
    buf:write_int32(leaver_eid)
    local pkt = buf:to_string()
    for _, gw in ipairs(instance.member_gateways(inst)) do
        player.send_packet(gw, OP_SM_INSTANCE_MEMBER_LEAVE, pkt)
    end
end

local function _send_reward(gw, inst, kinah, items)
    local buf = bytes.new()
    buf:write_int64(inst.id)
    buf:write_int64(kinah or 0)
    local ic = (items and #items) or 0
    buf:write_int32(ic)
    for i = 1, ic do
        buf:write_int32(items[i].id or 0)
        buf:write_int32(items[i].count or 0)
    end
    player.send_packet(gw, OP_SM_INSTANCE_REWARD, buf:to_string())
end

-- ----------------------------------------------------------------------------
-- instance.create — two-phase commit per plan §Lifecycle.
-- Returns: run_id (int64 > 0), reason (string | nil on OK).
-- On failure returns: nil, reason, blocking_char_id? (when applicable).
-- ----------------------------------------------------------------------------

local function _cooldown_row_for(cid, template_id)
    -- Query all instance rows for the character, filter in Lua for the
    -- template we care about. The SP may return multiple rows (different
    -- template_ids); linear scan is fine since rows are small.
    if not db then return nil, nil end
    local rows, err = db.call("aion_getuserinstance_20171122", cid)
    if err then return nil, err end
    if not rows then return nil, nil end
    for _, r in ipairs(rows) do
        local iid = tonumber(r.instance_id or r.InstanceID or 0) or 0
        if iid == template_id then
            return r, nil
        end
    end
    return nil, nil
end

instance.create = function(leader_eid, template_id)
    template_id = math.floor(tonumber(template_id) or 0)
    local tmpl = _templates[template_id]
    if not tmpl then
        return nil, "template_unknown"
    end

    -- If leader is already in a run of this template, redirect to rejoin.
    local existing_run = _char_run[_char_id(leader_eid)]
    if existing_run and _instances[existing_run]
       and _instances[existing_run].template_id == template_id
       and _instances[existing_run].state ~= instance.STATE_EXPIRED then
        return nil, "already_in_instance"
    end

    -- Resolve the leader's party; solo is modelled as a singleton list.
    local party_eids
    if group and group.members then
        party_eids = group.members(leader_eid)
    end
    if not party_eids or #party_eids == 0 then
        party_eids = { leader_eid }
    else
        -- Confirm caller is the party leader; non-leaders cannot create.
        local g = group.get and group.get(leader_eid)
        if g and g.leader ~= leader_eid then
            return nil, "not_leader"
        end
    end

    if #party_eids < tmpl.min_members then
        return nil, "bad_group_size"
    end
    if #party_eids > tmpl.max_members then
        return nil, "bad_group_size"
    end

    -- Phase 1: read-only validation.
    local leader_level = _level(leader_eid)
    local leader_x, leader_y, leader_z
    do
        local p = entity.get_position(leader_eid)
        leader_x, leader_y, leader_z = p.x, p.y, p.z
    end

    local skip_sp_write = {}   -- set of char_ids for crash-recovery members

    for _, m in ipairs(party_eids) do
        local gw = entity.get_gateway_id(m)
        if not gw then
            return nil, "member_offline"
        end
        if not _alive(m) then
            return nil, "member_dead"
        end
        local lvl = _level(m)
        if lvl < tmpl.min_level or lvl > tmpl.max_level then
            return nil, "bad_level"
        end
        -- Distance check: members must be within 50m of the leader to enter.
        -- Skip for the leader themselves.
        if m ~= leader_eid then
            local p = entity.get_position(m)
            local dx, dy, dz = p.x - leader_x, p.y - leader_y, p.z - leader_z
            if dx * dx + dy * dy + dz * dz > 50 * 50 then
                return nil, "member_out_of_range"
            end
        end

        local cid = _char_id(m)
        if cid <= 0 then
            return nil, "member_no_char_id"
        end

        local row, err = _cooldown_row_for(cid, template_id)
        if err then
            return nil, "db_error"
        end
        if row then
            local reentry = tonumber(row.reentrance_time or 0) or 0
            if reentry > os.time() then
                -- Cooldown active. Two sub-cases:
                --   (a) _char_run[cid] points at a live run → hard reject
                --   (b) _char_run[cid] empty → crash-recovery re-entry;
                --       do NOT re-bump the cooldown (plan round 2 issue #5)
                if _char_run[cid] and _instances[_char_run[cid]]
                   and _instances[_char_run[cid]].template_id == template_id then
                    return nil, "cooldown", cid
                else
                    skip_sp_write[cid] = true
                end
            end
        end
    end

    -- Phase 2: commit with compensation rollback.
    local run_id = _next_run_id
    _next_run_id = _next_run_id + 1

    local now = os.time()
    local inst = {
        id              = run_id,
        created_at_unix = now,
        template_id     = template_id,
        creator_eid     = leader_eid,
        creator_char_id = _char_id(leader_eid),
        members         = {},
        state           = instance.STATE_LOBBY,
        created_tick    = current_tick or 0,
        cleared_tick    = nil,
        expires_at_sec  = now + tmpl.validity_hours * 3600,
        boss_eid        = nil,
        rewards_given   = false,
    }

    local committed = {}   -- rollback list: char_ids with freshly-bumped cooldown
    local reentry   = now + tmpl.reentrance_sec

    for _, m in ipairs(party_eids) do
        local cid = _char_id(m)
        if not skip_sp_write[cid] then
            -- Phase 2 SP write. If db is not wired (dev / unit-test without an
            -- installed stub) we still register in-memory membership but skip
            -- the cooldown SP — the test fixtures that care about the DB call
            -- count install _G.db explicitly.
            local serr = nil
            if db then
                local _
                _, serr = db.call("aion_setuserinstance_20171122",
                    cid, template_id, template_id, reentry,
                    _server_id(), 0, 0, 0, 0)
            end
            if serr then
                -- Rollback: revert cooldown for every committed char (reentry=0
                -- acts as "clear cooldown" in the NCSoft schema).
                log.warn("instance.create: SP failure, rolling back cid=" .. tostring(cid)
                    .. " err=" .. tostring(serr))
                for i = #committed, 1, -1 do
                    local c = committed[i]
                    if db then
                        db.call("aion_setuserinstance_20171122",
                            c, template_id, template_id, 0,
                            _server_id(), 0, 0, 0, 0)
                    end
                end
                return nil, "db_error", cid
            end
            committed[#committed + 1] = cid
        end
        -- Register membership (both indexes) and teleport.
        _char_run[cid]        = run_id
        _member_instance[m]   = run_id
        entity.set_stat(m, "instance_run_id", run_id)
        entity.set_position(m, tmpl.spawn_x, tmpl.spawn_y, tmpl.spawn_z)
        inst.members[#inst.members + 1] = m
    end

    _instances[run_id] = inst

    -- Schedule expiry (plan round 2 issue #1: include created_at_unix so the
    -- callback can reject stale fires after a World Engine restart recycled
    -- the run_id counter).
    if jobq then
        local ok, reason = jobq.enqueue(
            "aion58.instance.expire",
            { run_id = run_id, created_at_unix = now },
            tmpl.validity_hours * 3600)
        if not ok and reason ~= "disabled" then
            log.warn("instance.create: expiry enqueue failed reason="
                .. tostring(reason))
        end
    end

    -- Spawn the boss NPC and tag it with the run_id.
    if tmpl.boss_template and world and world.spawn_npc then
        local beid = world.spawn_npc(tmpl.boss_template,
            tmpl.boss_x or tmpl.spawn_x,
            tmpl.boss_y or tmpl.spawn_y,
            tmpl.boss_z or tmpl.spawn_z)
        if beid and beid > 0 then
            inst.boss_eid = beid
            entity.set_stat(beid, "instance_run_id", run_id)
        end
    end

    inst.state = instance.STATE_ACTIVE
    _bcast_state(inst)
    for _, m in ipairs(inst.members) do _bcast_member_join(inst, m) end

    log.info("instance.create: run_id=" .. tostring(run_id)
        .. " template_id=" .. tostring(template_id)
        .. " members=" .. tostring(#inst.members))
    return run_id, nil
end

-- ----------------------------------------------------------------------------
-- instance.rejoin — a player whose _char_run is still registered reconnects
-- and re-enters the same run without paying cooldown a second time.
-- ----------------------------------------------------------------------------

instance.rejoin = function(eid, template_id)
    local cid = _char_id(eid)
    local run_id = _char_run[cid]
    if not run_id then return false, "no_prior_run" end
    local inst = _instances[run_id]
    if not inst or inst.state == instance.STATE_EXPIRED then
        _char_run[cid] = nil
        return false, "run_gone"
    end
    if inst.template_id ~= math.floor(tonumber(template_id) or 0) then
        return false, "template_mismatch"
    end

    -- Add back to live members (dedupe).
    local present = false
    for _, m in ipairs(inst.members) do
        if m == eid then present = true; break end
    end
    if not present then
        inst.members[#inst.members + 1] = eid
    end
    _member_instance[eid] = run_id
    entity.set_stat(eid, "instance_run_id", run_id)

    local tmpl = _templates[inst.template_id]
    if tmpl then
        entity.set_position(eid, tmpl.spawn_x, tmpl.spawn_y, tmpl.spawn_z)
    end

    _bcast_member_join(inst, eid)
    return true, nil
end

-- ----------------------------------------------------------------------------
-- instance.leave — voluntary exit, disconnect sweep, or group-kick callback.
-- Does NOT dispose the run even on #members==0 (plan round 1 issue #1).
-- ----------------------------------------------------------------------------

instance.leave = function(eid)
    local run_id = _member_instance[eid]
    if not run_id then return false, "not_in_instance" end
    local inst = _instances[run_id]
    if not inst then
        _member_instance[eid] = nil
        return false, "run_gone"
    end

    -- Remove from live-members list (keep _char_run intact).
    for i, m in ipairs(inst.members) do
        if m == eid then
            table.remove(inst.members, i)
            break
        end
    end
    _member_instance[eid] = nil
    entity.set_stat(eid, "instance_run_id", 0)

    -- Teleport back to bind point (best-effort; if SP missing, leave them put).
    if db then
        local bind, err = db.call("aion_GetBindPoint", _char_id(eid))
        if not err and bind and bind[1] then
            local bx = tonumber(bind[1].x or bind[1].X or 0) or 0
            local by = tonumber(bind[1].y or bind[1].Y or 0) or 0
            local bz = tonumber(bind[1].z or bind[1].Z or 0) or 0
            entity.set_position(eid, bx, by, bz)
        end
    end

    _bcast_member_leave(inst, eid)
    log.info("instance.leave: run_id=" .. tostring(run_id)
        .. " eid=" .. tostring(eid)
        .. " remaining=" .. tostring(#inst.members))
    return true, nil
end

-- ----------------------------------------------------------------------------
-- instance.on_boss_kill — hook fired from scripts/events/on_kill.lua for each
-- NPC death. Returns true if the victim was the boss of some active run so the
-- caller can short-circuit its normal NPC-kill processing.
-- ----------------------------------------------------------------------------

instance.on_boss_kill = function(victim_eid, killer_eid)
    for _, inst in pairs(_instances) do
        if inst.state ~= instance.STATE_EXPIRED
           and inst.boss_eid == victim_eid
           and not inst.rewards_given then

            inst.rewards_given = true
            inst.state         = instance.STATE_CLEARED
            inst.cleared_tick  = current_tick or 0

            local tmpl = _templates[inst.template_id]
            local rewards = tmpl and tmpl.rewards or { kinah = 0, items = {} }

            for _, m in ipairs(inst.members) do
                local gw = entity.get_gateway_id(m)
                if gw then
                    if rewards.kinah and rewards.kinah > 0 then
                        player.add_kinah(gw, rewards.kinah)
                    end
                    if rewards.items then
                        for _, it in ipairs(rewards.items) do
                            if it.id and it.count and it.count > 0 then
                                -- Round 6 C4 — entropy v0 wiring: 副本 boss 击杀奖励是"巅峰熵刻"，
                                -- 按 epic tier 放满 6 槽 greater manastone，feel "这把要留着"。
                                -- TODO Cycle 17: instance template rewards 表应该自带 item_class 字段。
                                entropy.add_item_with_stones(gw, it.id, it.count, "weapon", "epic", season_seed())
                            end
                        end
                    end
                    _send_reward(gw, inst, rewards.kinah or 0, rewards.items)
                end
            end

            _bcast_state(inst)
            log.info("instance.on_boss_kill: run_id=" .. tostring(inst.id)
                .. " template_id=" .. tostring(inst.template_id))

            -- Allow the template to run a custom post-clear hook (e.g. despawn
            -- adds, open the exit portal NPC, queue a cinematic).
            if tmpl and tmpl.on_boss_kill then
                pcall(tmpl.on_boss_kill, inst, victim_eid)
            end
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- instance.reset — pay kinah to clear the cooldown on a template the player is
-- not currently inside. Clears _char_run for that template so a fresh create()
-- is allowed.
-- ----------------------------------------------------------------------------

instance.reset = function(eid, template_id)
    template_id = math.floor(tonumber(template_id) or 0)
    local tmpl = _templates[template_id]
    if not tmpl then return false, "template_unknown" end

    local gw = entity.get_gateway_id(eid)
    if not gw then return false, "not_online" end

    local cid = _char_id(eid)
    if cid <= 0 then return false, "no_char_id" end

    -- Reject if the player is currently inside a run of this template (they
    -- must leave first).
    local active = _char_run[cid]
    if active and _instances[active]
       and _instances[active].template_id == template_id
       and _member_instance[eid] == active then
        return false, "currently_in_run"
    end

    local fee = tmpl.reset_fee_kinah or 0
    if fee > 0 and not player.spend_kinah(gw, fee) then
        return false, "no_kinah"
    end

    if db then
        local _, err = db.call("aion_setuserinstance_20171122",
            cid, template_id, template_id, 0,
            _server_id(), 0, 0, 0, 0)
        if err then
            if fee > 0 then player.add_kinah(gw, fee) end
            log.warn("instance.reset: SP err=" .. tostring(err))
            return false, "db_error"
        end
    end

    _char_run[cid] = nil
    log.info("instance.reset: cid=" .. tostring(cid)
        .. " template_id=" .. tostring(template_id))

    -- Refresh the cooldown list for the UI.
    instance.send_cooldowns(eid)
    return true, nil
end

-- ----------------------------------------------------------------------------
-- instance.send_cooldowns — push SM_INSTANCE_COOLDOWNS (0xD5) to the player
-- with the full set of active cooldowns pulled from aion_getuserinstance.
-- ----------------------------------------------------------------------------

instance.send_cooldowns = function(eid)
    local gw = entity.get_gateway_id(eid)
    if not gw or not db then return end

    local cid = _char_id(eid)
    if cid <= 0 then return end

    local rows, err = db.call("aion_getuserinstance_20171122", cid)
    if err or not rows then return end

    local now  = os.time()
    local keep = {}
    for _, r in ipairs(rows) do
        local reentry = tonumber(r.reentrance_time or 0) or 0
        if reentry > now then
            keep[#keep + 1] = {
                iid     = math.floor(tonumber(r.instance_id or 0) or 0),
                reentry = reentry,
            }
        end
    end

    local buf = bytes.new()
    buf:write_int32(#keep)
    for _, e in ipairs(keep) do
        buf:write_int32(e.iid)
        buf:write_int32(e.reentry)
    end
    player.send_packet(gw, OP_SM_INSTANCE_COOLDOWNS, buf:to_string())
end

-- ----------------------------------------------------------------------------
-- instance.on_expire — jobq callback. Drops the run ONLY if the payload's
-- created_at_unix matches the in-memory record; otherwise logs a warn and
-- returns (prevents stale-expire misfire across restarts).
-- ----------------------------------------------------------------------------

instance.on_expire = function(run_id, created_at_unix)
    run_id          = tonumber(run_id) or 0
    created_at_unix = tonumber(created_at_unix) or 0

    local inst = _instances[run_id]
    if not inst then
        log.warn("instance.on_expire: run_id=" .. tostring(run_id) .. " no such run")
        return
    end
    if created_at_unix ~= inst.created_at_unix then
        log.warn("instance.on_expire: stale (created_at mismatch) run_id="
            .. tostring(run_id)
            .. " payload=" .. tostring(created_at_unix)
            .. " inst=" .. tostring(inst.created_at_unix))
        return
    end

    -- Kick remaining members (teleport to bind) then dispose.
    local snapshot = {}
    for _, m in ipairs(inst.members) do snapshot[#snapshot + 1] = m end
    for _, m in ipairs(snapshot) do instance.leave(m) end

    inst.state = instance.STATE_EXPIRED
    _bcast_state(inst)

    if inst.boss_eid and world and world.despawn then
        world.despawn(inst.boss_eid)
    end

    -- Sweep _char_run entries that still point at this run.
    for cid, rid in pairs(_char_run) do
        if rid == run_id then _char_run[cid] = nil end
    end

    _instances[run_id] = nil
    log.info("instance.on_expire: disposed run_id=" .. tostring(run_id))
end

-- ----------------------------------------------------------------------------
-- Read-only accessors (used by cm_enter_world crash-recovery guard and tests).
-- ----------------------------------------------------------------------------

instance.get = function(run_id) return _instances[run_id] end

instance.get_by_eid = function(eid) return _instances[_member_instance[eid] or 0] end

instance.has_char_run = function(char_id) return _char_run[math.floor(char_id or 0)] end

-- ----------------------------------------------------------------------------
-- Group-coupling: subscribe to group.kick / group.leave so a player ejected
-- from their party mid-instance is also ejected from the instance (plan
-- round 2 issue #6). Uses the hook registry added to group.lua.
-- ----------------------------------------------------------------------------

if group and group.register_kick_handler then
    group.register_kick_handler(function(kicked_eid)
        if _member_instance[kicked_eid] then
            instance.leave(kicked_eid)
        end
    end)
end
if group and group.register_leave_handler then
    group.register_leave_handler(function(left_eid)
        if _member_instance[left_eid] then
            instance.leave(left_eid)
        end
    end)
end
