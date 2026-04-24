# AionCore 5.8

English: [README.md](README.md)

基于 Go + Lua 对 NCSoft AION 5.8 分布式游戏服务端的重新实现。

## 架构

```
5.8 客户端 ──► 协议网关 (Go, BF/RSA/XOR 编解码)
                       │ NATS JetStream
                       ▼
                世界引擎 (Go ECS + Lua VM)
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     PostgreSQL     Redis      ClickHouse
    (1314 存储过程) (会话缓存)    (日志)
```

**设计原则**：Go 作为薄运行时，只负责网络、加密、数据库连接池、ECS 与 VM 宿主；所有业务逻辑交给 Lua 承载——热加载、无需编译、无需重启。

## 服务清单

| 服务 | 代码位置 | 端口 (prod / dev) | 职责 |
|------|---------|-------------------|------|
| Gateway | `server/src/cmd/gateway/` | 2108,7777 / 2208,7877 | AION 协议编解码，不含任何游戏逻辑 |
| World | `server/src/cmd/world/` | — | ECS 主循环 + Lua VM，承载全部游戏逻辑 |
| Chat | `server/src/cmd/chat/` | 10241 | 频道聊天，可独立横向扩展 |
| LogD | `server/src/cmd/logd/` | — | 异步日志管线，写入 ClickHouse |
| Admin | `server/src/cmd/admin/` | 8080 | REST API + Web 管理面板 |

## 目录结构

```
server/
├── src/                     Go 源码
│   ├── cmd/                 5 个服务二进制入口
│   └── internal/
│       ├── aionproto/       AION 封包编解码与 opcode
│       ├── crypto/          Blowfish-LE、RSA-NoPad、XOR（NCSoft 兼容）
│       ├── ecs/             实体-组件-系统框架
│       ├── luahost/         Lua VM 池、Go⇄Lua 桥、热加载
│       ├── jobq/            后台任务队列 (river + asynq)
│       ├── database/        pgx 连接池封装
│       ├── session/         玩家会话管理
│       ├── ipc/             NATS 服务间消息
│       ├── config/          TOML 热加载
│       └── telemetry/       指标与追踪
├── scripts/                 Lua 业务逻辑 (75 个文件)
│   ├── handlers/            封包处理器 (cm_move, cm_attack, ...)
│   ├── lib/                 共享模块 (pvp, mail, auction, legion, ...)
│   ├── events/              事件钩子 (on_tick, on_kill, on_auction_expire, ...)
│   ├── skills/              单技能脚本 (skill_1001, ...)
│   ├── combat/              伤害公式、命中判定
│   ├── ai/                  NPC 行为
│   ├── quests/              任务状态机
│   └── npcs/                NPC 模板
├── sql/                     PostgreSQL schema 与种子数据
├── config/                  基础 TOML 配置
├── doc/                     文档
│   ├── dev-guide.md         开发权威文档 (Source of Truth)
│   └── migration/           NCSoft SQL Server → PostgreSQL 迁移工具
└── launcher/                Tauri 客户端启动器

dev/                         开发环境 (端口 +100，倍率 10x)
prod/                        生产环境 (真实玩家)
```

## 快速上手

### 前置依赖

- Go 1.25+
- PostgreSQL 16+，并已部署 1314 个 PL/pgSQL 存储过程
- Redis 7+
- NATS Server 2.10+

### 编译

```bash
cd server/src
go build ./cmd/...
```

### 运行（开发环境）

```bash
# 二进制产物复制到 dev 环境
cp gateway world chat logd admin ../../dev/bin/

# 启动服务
./dev/bin/gateway -config dev/config/gateway.toml
./dev/bin/world   -config dev/config/world.toml
```

Dev 环境：端口 2208/7877，经验/掉落 10x，debug 日志，玩家上限 50。

### 运行（生产环境）

```bash
cp gateway world chat logd admin ../../prod/bin/
./prod/bin/gateway -config prod/config/gateway.toml
./prod/bin/world   -config prod/config/world.toml
```

生产环境：端口 2108/7777，标准倍率，info 日志，玩家上限 1800。

### 测试

```bash
cd server/src
go test ./...          # 224 个测试，全绿
go test ./... -v       # 详细输出
```

## 已实现阶段

| 阶段 | 功能 | 测试 |
|------|------|------|
| S-0 ~ S-5 | 核心运行时：加密、ECS、协议编解码、Lua VM 池、热加载 | 30 |
| S-6 | NPC 对话与商店系统 | +14 |
| S-7 | 组队系统 | +12 |
| S-8 | 技能系统 | +10 |
| S-9 | 任务引擎 | +12 |
| S-10 | 军团（公会）系统 | +14 |
| S-11 | PvP 战斗与深渊点数 | +12 |
| S-12 | 装备系统（15 槽位） | +20 |
| S-13 | 后台任务队列 (river + asynq) | +10 |
| S-14 | 邮件系统 | +24 |
| S-15 | 仓库（账号仓） | +17 |
| S-16 | 拍卖行 | +27 |
| S-17 | LuaInvoker 桥接（Go→Lua，供后台 worker 调用） | +12 |
| **合计** | | **224** |

## 关键技术决策

- **Blowfish 使用小端序** —— NCSoft 非标准做法，需要自定义实现
- **XOR 顺序：先 XOR 再 ADD，种子 1234** —— 与 AL-Login 的顺序不同
- **账号名最长 17 字节** —— RSA 凭据块大小限制
- **SQL 一律走存储过程** —— 1314 个已迁移的 PL/pgSQL 函数，禁止内联 SQL
- **PostgreSQL 仅监听 127.0.0.1** —— 绝不暴露公网
- **任务队列**：river（基于 PG，事务型） + asynq（基于 Redis，定时/延时型）

## 配置

全部采用 TOML，支持热加载：

| 文件 | 用途 |
|------|------|
| `gateway.toml` | 端口、加密密钥、DB/Redis 连接 |
| `world.toml` | Tick 频率、玩家上限、Lua VM 参数 |
| `rates.toml` | 经验/掉落/Kinah 倍率（改动免重启） |

## 新增游戏逻辑

```bash
# 新技能 —— 1 秒内生效，无需重启
echo 'function on_use(caster, target) ... end' > server/scripts/skills/skill_XXXX.lua

# 新封包处理器
echo 'function handle(session, pkt) ... end' > server/scripts/handlers/cm_xxxx.lua

# 调整掉落倍率 —— 保存即热加载
vim server/config/rates.toml
```

业务逻辑变更不需要改动任何 Go 代码。

## 三轨并行架构

AionCore 同时维护三条实现线路，它们共享同一套 Lua 脚本与存储过程：

| 轨道 | 语言 | 状态 |
|------|------|------|
| **A**（本仓库） | Go + Lua | 主线开发中 |
| **D** | C++20 | 归档参考线（BF/RSA/XOR 比对验证用） |
| **E** | Rust + mlua | 早期开发中 |

`server/scripts/` 下的 Lua 脚本层与 PL/pgSQL 存储过程构成语言无关的契约层，是三条轨道之间的统一绑定面。

## 许可证

私有项目，保留所有权利。
