# AionCore 5.8 架构总览 / Architecture Reference

> **配套阅读**：[`dev-guide.md`](./dev-guide.md)（硬约束/反模式）·
> [`opcodes.md`](./opcodes.md)（协议字典）· [`lua-api.md`](./lua-api.md)（Bridge API）·
> [`../README.zh-CN.md`](../README.zh-CN.md)（中文入口）。
>
> 本文聚焦 **结构** 与 **数据流**；硬约束不在这里重复。

---

## 0. 速览 / Overview

```
                       ┌──────────────────────────┐
                       │   5.8 Game Client        │
                       │   (NCSoft binary, 35 GB) │
                       └─────────┬────────────────┘
                                 │ TCP（BF-LE + RSA + XOR）
                ┌────────────────┴─────────────────┐
                │                                   │
        :2108 (Auth)                          :7777 (Game)
                │                                   │
                ▼                                   ▼
        ┌──────────────────────────────────────────────────┐
        │  gateway (Go)                                     │
        │  · Blowfish-LE / RSA-1024 / XOR(seed=1234) codec  │
        │  · session keying + SM_KEY 握手                   │
        │  · 把 CM_* 解码后转发到 NATS subjects             │
        │  · 把 SM_* 取自 NATS 后加密下发客户端             │
        │  · ZERO 业务逻辑                                  │
        └────────────────────────┬─────────────────────────┘
                                 │ NATS JetStream
        ┌────────────────────────┴─────────────────────────┐
        │  world (Go)                                       │
        │  · ECS 实体组件系统 (entity / position / stat …) │
        │  · gopher-lua VM 池                               │
        │  · luahost.Bridge：注入 log/db/entity/player/…   │
        │  · jobq 异步任务（拍卖到期 / 副本到期 / 邮件）    │
        │  · scripts/ 1 秒热重载                            │
        └─┬───────────────┬───────────────┬─────────────────┘
          │               │               │
          ▼               ▼               ▼
     ┌──────────┐    ┌─────────┐    ┌──────────────────┐
     │ pgx pool │    │ Redis   │    │ NATS（同上回环） │
     │ aion_*   │    │ session │    │ chat / logd /    │
     │ (1314 SP)│    │ token   │    │ admin            │
     └──────────┘    │ rate    │    └──────────────────┘
                     │ cache   │
                     └─────────┘
```

旁支：

```
chat (Go, :10241)   独立可扩展的频道聊天（与 world 解耦）
logd (Go)           异步日志管道（→ 未来 ClickHouse）
admin (Go, :8080)   REST + Web dashboard
tinyclient (Go)     端到端 smoke 客户端（不在生产里跑）
```

---

## 1. 三层职责矩阵 / Layer Responsibility Matrix

| 维度 | Go Runtime（Layer 1） | Lua Scripts（Layer 2） | PostgreSQL SP（Layer 3） |
|------|----------------------|------------------------|--------------------------|
| **代码量占比** | ~10% | ~85% | ~5%（手写迁移层） |
| **变更频率** | 月级 | 日级 / 小时级 | 周级 |
| **重启需求** | 必须重启进程 | 1 秒热重载 | 直接 `psql` 替换 |
| **典型例子** | TCP server / pgx pool / blowfish / ECS 框架 | CM_USE_SKILL handler / 副本流程 / NPC 对话 | 角色读写 / 物品 CRUD / 邮件投递 / 拍卖结算 |
| **token 成本** | 高（~3000/改） | 低（~500/改） | 中（按 SP 大小） |
| **测试机制** | `go test ./internal/...` | `luahost` VM-driven 测试 + Lua mock | `database` 集成测试（连真 PG） |
| **能不能写 SQL** | **❌ 不能** | **❌ 不能** | ✅ 唯一允许处 |
| **能不能写游戏逻辑** | **❌ 不能** | ✅ **唯一允许处** | 部分（数据完整性约束） |

**金律**：90% 的改动应该落在 Layer 2。如果发现要改 Layer 1，先 stop and think — 是不是该做成
Lua API + Bridge 注入？

---

## 2. 进程拓扑 / Process Topology

| 进程 | 端口 | 职责 | 依赖 | 当前状态 |
|------|------|------|------|----------|
| **gateway** | 2108(auth) / 7777(game) | AION 协议编解码 / 握手 / NATS 桥接 | NATS · Redis(session) | 完整实现 |
| **world** | — | ECS · Lua VM · jobq · 业务 | NATS · Redis · PostgreSQL | 完整实现 |
| **chat** | 10241 | 频道聊天 / shout / whisper 路由 | NATS · Redis | stub（boot 不 panic） |
| **logd** | — | 异步日志聚合 → ClickHouse | NATS | stub |
| **admin** | 8080 | REST + Web dashboard | PostgreSQL | stub |

**拆分理由**：
- `gateway` 单独一进程：crypto / 包帧是 CPU 密集 + 长连接管理，且需要独立水平扩展。
- `world` 单独一进程：ECS + Lua VM 是 in-memory + 单线程模型，跨进程共享代价高。
- `chat / logd / admin` 单独：各自有独立的 SLA / 扩缩需求，挂掉不影响主战斗循环。

---

## 3. 通信协议层级 / Wire Protocol Layers

```
┌───────────────────────────────────────────────────────┐
│  TCP byte stream                                       │
└───────┬───────────────────────────────────────────────┘
        │ 包帧（前 2 字节 = 长度 LE，含自身）
        ▼
┌───────────────────────────────────────────────────────┐
│  Frame: [u16 length] [payload...]                      │
│         length 包括 length 字段本身，最小 3            │
└───────┬───────────────────────────────────────────────┘
        │ 客户端→服务器：先 XOR 解密 (seed=1234)
        │ 服务器→客户端：直接 BF
        ▼
┌───────────────────────────────────────────────────────┐
│  After XOR: [u16 length] [BF-LE encrypted blob]        │
└───────┬───────────────────────────────────────────────┘
        │ Blowfish-LE 解密（注意：小端，标准库 crypto/blowfish 不能用）
        ▼
┌───────────────────────────────────────────────────────┐
│  Cleartext: [u16 length] [opcode] [body]               │
│  Auth port (:2108) opcode 是 u8                        │
│  Game port (:7777) opcode 是 u16                       │
└───────────────────────────────────────────────────────┘
```

opcode 命名约定：`CM_*` = Client→Server，`SM_*` = Server→Client。完整 opcode 字典见
[`opcodes.md`](./opcodes.md)（已分配 0x00–0xD7，0xD8–0xFF 留给 S-20+ 宠物/家园/战场/玩家交易）。

特殊例外：
- `SM_KEY`（0x00）首包不加密，承载 RSA pubkey 模数 + 静态 BF key。
- 5.8 客户端 **忽略 XOR 校验位**——服务端要容忍校验失败仍接收数据。
- `CM_AUTH_LOGIN`（0x01）凭据是 RSA-1024 加密的；账号名 ≤ 17 字符（RSA 块大小硬限）。

参考实现：`src/internal/aionproto/`（编解码 + opcode 常量）+ `src/internal/crypto/`（BF-LE/RSA/XOR）。

---

## 4. 数据流 / Data Flow

### 4.1 登录链路

```
Client → gateway: TCP connect :2108
gateway → Client: SM_KEY (0x00, 不加密；RSA 模数 + BF static key)
Client → gateway: CM_AUTH_LOGIN (0x01, RSA 加密凭据)
gateway: RSA 解密 → db.call("ap_verify_account") → SP 校验
gateway → Redis: SETEX session:<token> { account_id, ... }
gateway → Client: SM_LOGIN_OK (0x02, 服务器列表) | SM_LOGIN_FAIL (0x03, 原因码)
Client → gateway: CM_PLAY (0x05, 选服)
gateway → Client: SM_PLAY_OK (0x06, 含 game-port session token)
———— 切换到 :7777 ————
Client → gateway: CM_VERSION_CHECK (0x0B)
gateway → Client: SM_VERSION_CHECK_OK (0x0C) + SM_SESSION_KEY (0x1A)
Client → gateway: CM_SESSION_CONFIRM (0x1B, 凭 token)
gateway → NATS: publish "player.enter" {account_id, gw_seq_id}
world ← NATS: subscribe "player.enter"
world: db.call("aion_get_character_list") → Lua scripts/handlers/cm_character_list.lua
world → NATS → gateway → Client: SM_CHARACTER_LIST (0x10)
Client → gateway: CM_ENTER_WORLD (0x15)
world: db.call(...) → Lua scripts/handlers/cm_enter_world.lua → ECS 装载
world → Client: SM_ENTER_WORLD_RESPONSE (0x16) + SM_PLAYER_INFO (0x34) + SM_INVENTORY_INFO (0x54) + ...
```

### 4.2 战斗 tick

```
Client → gateway: CM_USE_SKILL (0x0E, BF+XOR 加密)
gateway: 解密 → publish NATS "player.cm_use_skill" {gw_seq_id, payload}
world ← NATS: 取 payload → Lua scripts/handlers/cm_use_skill.lua
Lua: bytes.reader(payload) 拆字段 → combat.deal_damage(...) → entity.set_stat(...)
Lua: bytes.new() 装 SM_SKILL_RESULT(0x5E) → player.send_packet(gw, 0x5E, buf:to_string())
world → NATS → gateway → 加密 → Client: SM_SKILL_RESULT
（如造成死亡，combat.deal_damage 内部触发 events/on_kill.lua → SM_DIE 0x44）
```

### 4.3 副本进入（S-19）

```
Client → world(via gateway): CM_INSTANCE_ENTER (0xCF, template_id=300040000)
Lua scripts/handlers/cm_instance_enter.lua:
  1. instance.has_char_run(char_id) → 若有 → instance.rejoin (无需扣 cooldown)
  2. 否则 instance.create(leader_eid, template_id) →
     a. 第一阶段：所有成员 read-only validate (level/range/group_size/cooldown)
     b. 第二阶段：循环写每人 cooldown via aion_setuserinstance_20171122 SP
        中途失败 → 补偿回滚已写过的成员
  3. 成功后 jobq.enqueue("aion58.instance.expire", ..., validity_hours*3600)
  4. 全员 teleport 到 spawn_x/y/z
gateway → 全员: SM_INSTANCE_ENTER_RESULT (0xD0) + SM_INSTANCE_STATE (0xD2)
（boss 死亡触发 events/on_kill.lua → instance.on_boss_kill → SM_INSTANCE_REWARD 0xD3）
```

### 4.4 静态数据预载（Jay Lee 模式）

启动时 world 一次性把模板灌进 ECS 组件（不在运行时查 DB）：
- 物品模板 → ECS 组件
- NPC 模板 → ECS 组件
- 技能模板 → Lua skill registry（`scripts/skills/skill_*.lua` 自动加载）
- 任务模板 → Lua quest registry（`scripts/quests/quest_*.lua` 自动加载）
- 副本模板 → `instance.register{...}` 在 `scripts/instances/inst_*.lua` 中调用

**只有玩家个体数据走 SP**（角色 / 物品 / 邮件 / 拍卖 / 副本 cooldown / 公会成员）。

---

## 5. 状态持久化策略 / State Persistence

| 数据类型 | 落点 | 理由 |
|---------|------|------|
| 角色档案（HP/MP/level/exp/职业/坐标） | PG via SP | 跨进程跨重启；事务一致性 |
| 物品 / 装备 / 仓库 | PG via SP | 同上；防止重启丢物 |
| 邮件 / 拍卖 / 公会 | PG via SP | 跨玩家；离线投递 |
| 副本 cooldown | PG via `aion_setuserinstance_20171122` | 必须跨重启 |
| 副本 run 内部状态（哪个 boss 死了 / 进度） | ECS in-memory | 重启即作废，玩家可 reset 重进 |
| 在线玩家位置 / buff / 子弹 | ECS in-memory | tick 级写入，落 PG 浪费 |
| 会话 token / 反外挂状态 | Redis | 短 TTL；多进程共享 |
| Rate limiter / 缓存 | Redis | 同上 |
| 任务异步触发器（拍卖到期 / 副本到期 / 邮件投递） | jobq (asynq + Redis) | 延迟投递；重启续跑 |

**铁律**：永远不在 Go 或 Lua 里写裸 `INSERT/UPDATE/DELETE`。要写库 → 调对应 SP；没 SP →
先在 `sql/schema/00*_xxx.sql` 加，再迁移上线，再调用。

---

## 6. 热加载边界 / Hot-Reload Boundaries

| 资源 | 改动是否需要重启 | 实现机制 |
|------|------------------|----------|
| `scripts/**/*.lua` | **不需要**（≤1 秒生效） | luahost VM 池整池 swap，新 VM 加载新脚本，旧 VM 排空请求 |
| `config/*.toml` | **不需要**（fsnotify 监听） | `internal/config/` 提供 `config.rates(...)` / `config.get(...)` |
| Go 代码 | **必须**（重新 `go build` + `make stop && make boot`） | 没有 plugin 机制 |
| PG SP（`sql/schema/*.sql`） | **不需要**（直接 `psql` 替换函数定义） | PG 函数重定义无锁 |
| opcode 常量 (`opcodes.go`) | **必须**（Go 代码） | 同上 |

**Lua 热重载约束**：
- 不要在脚本里写持久 closure、长 timer。
- 状态放 ECS 组件（`entity.set_stat(...)`）或 Redis，不要放 module-level table。
- 每个脚本 `return table` 形态，不污染 global namespace。

---

## 7. 测试金字塔 / Test Pyramid

```
          ┌─────────────────────────────────────┐
          │  端到端 (boot-test)                  │
          │  make boot-test → tinyclient        │
          │  实际 5 进程 + NATS + Redis + PG    │
          │  ≈ 1 个                             │
          └─────────────────────────────────────┘
        ┌───────────────────────────────────────┐
        │  database 集成测试                     │
        │  连本地 PG 真库 → 跑 SP → 校验 DDL     │
        │  ≈ 几十个                              │
        └───────────────────────────────────────┘
      ┌─────────────────────────────────────────┐
      │  luahost 集成测试                        │
      │  起完整 VM 池 + 注入 mock ECS/DB         │
      │  覆盖 scripts/ 全 87 个文件的入口         │
      │  ≈ 上百个 (s14_test.go / s15_test.go …) │
      └─────────────────────────────────────────┘
    ┌───────────────────────────────────────────┐
    │  package 单测                              │
    │  crypto / aionproto / ecs / config / …    │
    │  pure Go，纯函数，<100 ms 跑全           │
    │  ≈ 200+                                    │
    └───────────────────────────────────────────┘
```

跑法（与 CI 等价）：

```bash
make lint    # go vet ./internal/...
make test    # go test ./internal/... -race -count=1 -timeout=5m
make cover   # 含 coverage.out + 末行总覆盖率
make bench   # crypto / luahost / database 微基准
```

各 pkg 覆盖率详见 [`coverage.md`](./coverage.md)；微基准基线见 [`benchmarks.md`](./benchmarks.md)。

---

## 8. 内部包速查 / Internal Package Map

```
src/internal/
├── aionproto/    AION 包编解码 · opcode 常量 · checksum
├── crypto/       Blowfish-LE / RSA-1024 / XOR(seed=1234)
├── database/     pgx pool · CallSP() · 嵌入式 goose 迁移
├── luahost/      gopher-lua VM 池 · Bridge.Register() · invoker
├── ecs/          实体-组件-系统（内存 / 单线程 / 单 world 实例）
├── jobq/         asynq 包装 · workers.go(kind→Lua global 映射)
├── ipc/          NATS 客户端封装 · subject 命名约定
├── config/       TOML 加载 · fsnotify 热重载 · rates / world / gateway
├── session/      gateway 会话状态机
├── telemetry/    slog 结构化日志 · metrics 接入
├── persona/      NPC 对话 personality / LLM prompt 装配
├── memory/       会话长期记忆 / Redis cache 抽象
├── spsynth/      PG SP 合成生成器（实验）
└── director/     副本 / 世界事件总线（实验）
```

每个包都遵循 "1 个 .go + 1 个 _test.go" 的最小骨架；超过 300 行就要拆。

---

## 9. 端口与外部依赖速查

| 端口 | 进程 | 用途 |
|------|------|------|
| 2108 | gateway | Auth 端口（CM_AUTH_LOGIN） |
| 7777 | gateway | Game 端口（CM_VERSION_CHECK 起） |
| 10241 | chat | 频道聊天 |
| 8080 | admin | REST + Web |
| 4222 | nats-server | JetStream |
| 6379 | devredis | session / jobq backing |
| 5432 | postgres | aion_world_live / aion_account_db / ... |

外部进程：
- `nats-server.exe` — `~/go/bin/`，由 Makefile `make boot` 自动启动
- `devredis.exe` — `tools/devredis/`，由 Makefile `make boot` 自动启动
- `postgres.exe` — Windows SCM 服务，**不由 Makefile 管理**（`make stop` 也不动它）

---

## 10. 后续路线指针

- 协议扩展 → [`opcodes.md`](./opcodes.md) "Unused / Reserved Ranges"，0xD9–0xFF 大段空闲
- Lua API 扩展 → 改 `src/internal/luahost/bridge.go` + 同步更新 [`lua-api.md`](./lua-api.md)
- 新 PG SP → `sql/schema/00NNN_xxx.sql` + 跑 `make test` 验证 + 在 Lua 用 `db.call("aion_xxx")`
- 高熵机制（modifier / affix / synergy）→ 已埋点 `entropy.forge_id` / `entropy.detect_synergy`，
  等 B 轨 PG SP 落地

---

*若架构变更，请同步本文 + [`../README.zh-CN.md`](../README.zh-CN.md) + [`../CLAUDE.md`](../CLAUDE.md)。*
