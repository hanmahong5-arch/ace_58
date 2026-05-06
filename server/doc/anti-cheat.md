# Anti-Cheat — 服务端权威校验

> AionCore 5.8 业务层反外挂。**纯服务端权威**：客户端时间戳和 client_ts 一律不信，所有判定吃 ECS 上次写入的坐标 + caller 注入的 server-side `current_tick`（20 Hz 单调递增）。
>
> 库实装：[`../scripts/lib/anti_cheat.lua`](../scripts/lib/anti_cheat.lua)
> 测试实装：`src/internal/luahost/anti_cheat_test.go`（11 PASS）
>
> 配套：[`./architecture.md`](./architecture.md)（Go/Lua 分层） · [`./runbook.md`](./runbook.md)

## 设计基线

| 维度 | 决策 | 为什么 |
|------|------|--------|
| 时间源 | server tick 20Hz，caller 注入 | 旧 AION 外挂套路 = 包重放 + client_ts 篡改；不信 client 时戳就根除一类攻击 |
| 坐标源 | ECS 权威（`entity.get_position`） | client 上报的 (x,y,z) 只是 *申请*，校验时和 ECS 上次写入的"上次合法坐标"作差 |
| 速度上限 | `DEFAULT_BASE_SPEED = 11.0 m/s × 1.5 容差` | 普通跑步 6m/s 骑乘 11m/s 翼飞约 15m/s；caller 飞行/坐骑场景**必须显式传** `base_speed=15` |
| APS 窗口 | 1 秒（20 ticks）滑动 | 卡 1Hz 稳态，防自动连击 / 加速器 |

**两层互不替代**：

- 业务层（本库）：包伪造 / 速度 / 距离 / CD / APS
- 客户端层（[ShiguangGate-v1](../../tools/ShiguangGate-v1/CLAUDE.md) 的 SM_KILL_CLIENT 等）：进程注入 / DLL / 内存 hack

## 公共 API（Lua）

```lua
local ac = anti_cheat   -- 全局；scripts/lib/anti_cheat.lua 顶层赋值

-- 1) 移动速度校验（含瞬移容忍）
local ok, reason = ac.check_move(eid, new_x, new_y, new_z, current_tick, base_speed)
-- reason ∈ { nil, "speed_hack", "tick_regression" }
-- base_speed 缺省 11 m/s；caller 必须按 stat（坐骑/翼飞）传更高值

-- 2) 攻击距离校验（基于 ECS 权威坐标）
local ok, reason = ac.check_attack(attacker_eid, target_eid, weapon_max_range)
-- reason ∈ { nil, "out_of_range" }；含 0.5m buffer

-- 3) 技能 CD 校验
local ok, reason = ac.check_skill_cd(eid, skill_id, current_tick, cd_ticks)
-- reason ∈ { nil, "cooldown" }

-- 4) APS 窗口（自动连击防御）
ac.record_attack(eid, current_tick)                       -- 记录一次合法攻击
local ok = ac.aps_within_limit(eid, current_tick, max_aps) -- 1 秒窗口内 <= max_aps

-- 玩家退出/复活/副本传送 必调
ac.reset(eid)
```

## 与 handler 的接线契约（**待合流**）

R5 swarm 时 handler 在另一会话 WIP（`cm_create_character.lua` / `cm_enter_world.lua` / `cm_revive.lua` 等），路径互斥**不能并行改 handler**。本库先做成独立模块，待 handler 合流后由后续 round 接：

### `cm_move`（待加）

```lua
local current_tick = world.tick()
local ok, reason = anti_cheat.check_move(eid, new_x, new_y, new_z, current_tick, get_base_speed(eid))
if not ok then
    log.warn("anti_cheat: " .. reason, "eid", eid)
    return  -- 直接丢包，让 client 自行回滚
end
entity.set_position(eid, new_x, new_y, new_z)
```

### `cm_attack`（待加）

```lua
local ok, reason = anti_cheat.check_attack(attacker_eid, target_eid, weapon_range)
if not ok then return end

if not anti_cheat.aps_within_limit(attacker_eid, current_tick, max_aps_for_class(eid)) then
    return  -- 自动连击防御
end

-- … 走伤害计算 …
anti_cheat.record_attack(attacker_eid, current_tick)
```

### `cm_skill_use`（待加）

```lua
local ok, reason = anti_cheat.check_skill_cd(eid, skill_id, current_tick, skill_cd_ticks(skill_id))
if not ok then return end
-- … 真正施放 …
```

### 退出 / 复活 / 副本传送

```lua
-- on_player_leave / cm_revive / instance.leave 都要调
anti_cheat.reset(eid)
```

> **不调 reset 的后果**：`_last_pos` / `_skill_last_tick` 等 upvalue 表无界增长，长期运行 → world 进程内存爬升直到 OOM。

## reason 码 → 处置建议

| reason | 含义 | 推荐处置 |
|--------|------|---------|
| `speed_hack` | 速度超阈值 | 拒包；累计 N 次/分 → kick + 标记疑似 |
| `tick_regression` | tick 回退（异常） | 拒包；通常是 reset 漏调，先排查 |
| `out_of_range` | 攻击距离超 | 拒包；常见为延迟下的边界，**不要立即 kick** |
| `cooldown` | 技能 CD 未到 | 拒包；客户端 UI 应同样拒绝，到这里说明客户端被改 |

## 已知 gap / TODO

1. **handler 接线未合流** — 本库目前是"陈列品"，必须等另一会话 handler WIP 落地后才接（参见 `project_engineering_sweep.md` 第五轮"5 lines waiting for merge"第 2 项）
2. **`DEFAULT_BASE_SPEED = 11 m/s` 不含翼飞** — 翼飞约 15 m/s；caller 必须按 stat 传 `base_speed`，否则飞行误判
3. **没有 SOD（state of detection）持久化** — 当前疑似行为只能落 slog，没有 `gm_audit_log` 表记录；接 PG SP `aion_LogCheatDetection` 是后续工作
4. **APS 窗口不区分技能类型** — 1 秒 X 次卡死，但近战/远程/法术合理上限不同；现版统一阈值，调用者按 class 传 `max_aps`
5. **没有跨进程一致性** — gateway/world 都接 anti_cheat 时各自独立 state；玩家在两进程间漂移可能漏校验。MVP 接受（5 进程间高频事件用 NATS 发 `aion58.anti_cheat.evict`）

## 测试

```bash
cd D:/拾光ai/ACE_5.8/server/src
go test ./internal/luahost -run TestAntiCheat -v -count=1
```

11 PASS：移动正常 / 速度作弊 / tick 回退 / 同 tick 合包 / 攻击距离 / CD 命中 / CD miss / APS 窗口饱和 / reset 清状态 / base_speed 注入 / 多 eid 隔离。
