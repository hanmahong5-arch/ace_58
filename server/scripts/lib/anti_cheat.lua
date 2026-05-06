-- scripts/lib/anti_cheat.lua
-- 服务端权威反外挂校验库（W4 standalone）。
--
-- WHY 不接 handler：
--   handler 改造（cm_create_character / cm_enter_world / cm_revive /
--   cm_warehouse_*）由另一会话 WIP，并行改 handler 会撞 git。本库先做成
--   独立模块，等 handler 合流后由后续 round 的会话/PR 接：
--       local ac = require_or_global("anti_cheat")
--       local ok, why = ac.check_move(eid, x, y, z, current_tick)
--
-- WHY 不信 client timestamp：
--   旧 AION 外挂套路 = 包重放 + 客户端 ts 篡改。常见手法是把 client_ts 推后
--   绕速率检查，或把 cd 起点改成上一帧导致服务端错认 cd 已过。本库所有时间
--   维度都吃 caller 注入的 server-side current_tick (单调递增 20 Hz)。
--
-- WHY 基于 ECS 权威坐标：
--   client 上报新坐标（x,y,z）只是 *申请*；服务端先用 entity.get_position()
--   读 ECS 上次写入的权威坐标，与 client 申请坐标做距离/速度差判定。所以
--   本库的 check_move(eid, new_x, new_y, new_z, tick) 中 new_* 是 client
--   *请求* 的坐标，与 ECS 当前坐标作差。
--
-- 三类校验：
--   1. move_speed: 两次上报间隔 vs 距离 → 过快拒绝（含瞬移容忍）
--   2. attack_range: 攻击者与目标 ECS 距离 vs 武器/技能 max_range
--   3. skill_cd: 技能上次施放 server_tick vs 现在 + 定义 cd → 早于则拒绝
--   4. APS 滑动窗口（防快攻自动连击）
--
-- 兜底分工：
--   - 包伪造 / 速度 / 距离 / CD —— 本库（业务层）
--   - 进程注入 / DLL / 内存 hack —— ShiguangGate-v1 SM_KILL_CLIENT 等外挂检测
--   两层互不替代。

anti_cheat = {}

-- ----------------------------------------------------------------------------
-- 内部状态（local upvalue）
-- ----------------------------------------------------------------------------
-- 玩家上次合法移动落点 + tick，用于下次 move 速度判定的 baseline。
--   _last_pos[eid] = { x, y, z, tick }
local _last_pos = {}

-- 玩家上次任何攻击的 tick（与 _attack_window 配合给 APS 用）。
local _last_attack_tick = {}

-- 每个 (eid, skill_id) 的上次施放 tick，用于 cd 检查。
--   _skill_last_tick[eid] = { [skill_id] = tick, ... }
local _skill_last_tick = {}

-- 攻击滑动窗口：每个 eid 一条按 tick 升序的环形 list。
--   _attack_window[eid] = { tick1, tick2, ... }
local _attack_window = {}

-- ----------------------------------------------------------------------------
-- 常量
-- ----------------------------------------------------------------------------
-- 速度上限默认值，单位 m/s。AION 普通跑步约 6 m/s，骑乘 11 m/s，
-- 翼飞约 15 m/s。给 1.5x 容差吸收网络抖动 + 服务端 tick 离散误差。
local DEFAULT_BASE_SPEED      = 11.0     -- m/s（保守覆盖跑步+骑乘）
local SPEED_TOLERANCE_FACTOR  = 1.5      -- 实际允许 1.5x base
-- 瞬移容忍：tick 间隔 < 这个阈值 (1 server tick ≈ 50ms @ 20Hz) 时不做速度判定。
-- 因为可能是同一逻辑帧内的多次合包重传，距离差不可信。
local MIN_TICK_INTERVAL       = 1
-- 攻击距离 buffer，吸收战斗中的位移 + 服务端 tick 离散误差。
local ATTACK_RANGE_BUFFER     = 0.5      -- m
-- APS 窗口 = 1 秒 = 20 ticks @ 20Hz。
local APS_WINDOW_TICKS        = 20

-- ----------------------------------------------------------------------------
-- 工具函数
-- ----------------------------------------------------------------------------
local function dist3d(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- 从 ECS 读权威坐标；entity 全局由 bridge.go 在 VM 启动时注入。
-- 返回 x, y, z 三个数（找不到则返回 0, 0, 0 并依赖 caller 的边界判断）。
local function ecs_pos(eid)
    if entity == nil or entity.get_position == nil then
        return 0, 0, 0
    end
    local p = entity.get_position(eid)
    if not p then return 0, 0, 0 end
    return p.x or 0, p.y or 0, p.z or 0
end

-- ----------------------------------------------------------------------------
-- 公共 API
-- ----------------------------------------------------------------------------

-- check_move(eid, new_x, new_y, new_z, current_tick [, base_speed])
--   返回 ok(boolean), reason(string|nil)
--   reason: "speed_hack" | nil
-- 第一次调用对该 eid（或 reset 后）只刷 baseline，直接 OK。
--
-- base_speed 解析顺序（caller override > ECS stat > 兜底常量）：
--   1) caller 显式传入 → 直接使用（测试 / 特殊载具调用方）
--   2) ECS 注入 stat "base_speed"（飞行/坐骑切状态时由 flight/mount 写入） → 使用
--   3) 都没有 → DEFAULT_BASE_SPEED 常量（11.0 m/s 跑步+骑乘保守值）
-- 注意：Go 的 entity.get_stat binding 在 stat 缺失时返回 0（非 nil），
--      故用 > 0 守卫排除 0 值，避免静默 0 m/s 把所有移动判成 speed_hack。
anti_cheat.check_move = function(eid, new_x, new_y, new_z, current_tick, base_speed)
    if not base_speed then
        local stat_speed = (entity and entity.get_stat)
            and entity.get_stat(eid, "base_speed") or 0
        if stat_speed > 0 then
            base_speed = stat_speed
        else
            base_speed = DEFAULT_BASE_SPEED
        end
    end
    local last = _last_pos[eid]
    -- 首次或 reset 后：写 baseline，免判定。
    if not last then
        _last_pos[eid] = { x = new_x, y = new_y, z = new_z, tick = current_tick }
        return true
    end

    local dt_ticks = current_tick - last.tick
    if dt_ticks < 0 then
        -- 时钟回退（异常）— 不更新 baseline，拒绝以防绕过。
        return false, "tick_regression"
    end
    if dt_ticks < MIN_TICK_INTERVAL then
        -- 同 tick 内合包，距离不可信；接受新坐标但不做速度判定。
        _last_pos[eid] = { x = new_x, y = new_y, z = new_z, tick = current_tick }
        return true
    end

    local d  = dist3d(last.x, last.y, last.z, new_x, new_y, new_z)
    -- ticks → 秒：1 tick = 0.05 s @ 20Hz。
    local dt = dt_ticks * 0.05
    local v  = d / dt
    if v > base_speed * SPEED_TOLERANCE_FACTOR then
        -- 不刷 baseline：让客户端继续被拒，直到回到合法位置。
        return false, "speed_hack"
    end

    _last_pos[eid] = { x = new_x, y = new_y, z = new_z, tick = current_tick }
    return true
end

-- check_attack(attacker_eid, target_eid, weapon_max_range)
--   返回 ok(boolean), reason(string|nil)
--   reason: "out_of_range" | nil
-- 距离来自 ECS 权威坐标；client 不能伪造（没有 client 输入参与）。
anti_cheat.check_attack = function(attacker_eid, target_eid, weapon_max_range)
    local ax, ay, az = ecs_pos(attacker_eid)
    local tx, ty, tz = ecs_pos(target_eid)
    local d = dist3d(ax, ay, az, tx, ty, tz)
    if d > (weapon_max_range or 0) + ATTACK_RANGE_BUFFER then
        return false, "out_of_range"
    end
    return true
end

-- check_skill_cd(eid, skill_id, current_tick, cd_ticks)
--   返回 ok(boolean), reason(string|nil)
--   reason: "cooldown" | nil
-- 首次施放 OK；记录 tick；下次必须 >= last + cd。
anti_cheat.check_skill_cd = function(eid, skill_id, current_tick, cd_ticks)
    local cds = _skill_last_tick[eid]
    if cds then
        local last = cds[skill_id]
        if last and current_tick < last + (cd_ticks or 0) then
            return false, "cooldown"
        end
    else
        cds = {}
        _skill_last_tick[eid] = cds
    end
    cds[skill_id] = current_tick
    return true
end

-- record_attack(eid, current_tick)
-- 把一次攻击记录进滑动窗口（由 cm_attack handler 在通过其他校验后调用）。
anti_cheat.record_attack = function(eid, current_tick)
    _last_attack_tick[eid] = current_tick
    local w = _attack_window[eid]
    if not w then
        w = {}
        _attack_window[eid] = w
    end
    w[#w + 1] = current_tick
    -- 截断：扔掉超出窗口的旧记录。
    local cutoff = current_tick - APS_WINDOW_TICKS
    local trimmed = {}
    for _, t in ipairs(w) do
        if t > cutoff then
            trimmed[#trimmed + 1] = t
        end
    end
    _attack_window[eid] = trimmed
end

-- aps_within_limit(eid, current_tick, max_aps)
--   返回 ok(boolean) — true = 当前 1 秒窗口内攻击次数 <= max_aps。
-- 注意：本函数 *不会* 自动 record；调用者通过 record_attack 显式喂数据，
-- 这样允许 handler 在做完所有其它校验后再决定是否计入窗口。
anti_cheat.aps_within_limit = function(eid, current_tick, max_aps)
    local w = _attack_window[eid]
    if not w then return true end
    local cutoff = current_tick - APS_WINDOW_TICKS
    local count = 0
    for _, t in ipairs(w) do
        if t > cutoff then count = count + 1 end
    end
    return count <= (max_aps or 0)
end

-- reset(eid)
-- 玩家断线 / 复活 / 进副本传送等场景下清理本库对该 eid 的全部内部状态。
-- ★ 必须在玩家退出时调用，否则 _last_pos 表无界增长 → 长期运行 OOM。
anti_cheat.reset = function(eid)
    _last_pos[eid]         = nil
    _last_attack_tick[eid] = nil
    _skill_last_tick[eid]  = nil
    _attack_window[eid]    = nil
end

-- _reset_all() — 仅供单测使用，清空全部内部表。
anti_cheat._reset_all = function()
    _last_pos         = {}
    _last_attack_tick = {}
    _skill_last_tick  = {}
    _attack_window    = {}
end
