# AionCore 5.8 Server (中文索引)

[![CI](https://github.com/<org>/<repo>/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/<org>/<repo>/actions/workflows/ci.yml)
[![Go Version](https://img.shields.io/badge/go-1.25-blue)](https://go.dev/)
[![License](https://img.shields.io/badge/license-Internal-lightgrey)](#)
[![Tests](https://img.shields.io/badge/tests-381%20pass-brightgreen)](#)
[![Coverage](https://img.shields.io/badge/coverage-69.5%25-yellow)](./doc/coverage.md)

> 中文 README · [English](./README.md) · [Architecture](./doc/architecture.md) · [Changelog](./CHANGELOG.md) · [Contributing](./CONTRIBUTING.md) · [ADRs](./doc/adr/README.md) · [Runbook](./doc/runbook.md)

> Go + Lua + PostgreSQL 自写的 NCSoft AION 5.8 私服核心。
>
> 本文是中文主入口。英文摘要见 [`README.md`](./README.md)；硬约束清单见
> [`doc/dev-guide.md`](./doc/dev-guide.md)；AI 协作守则见 [`CLAUDE.md`](./CLAUDE.md)。

---

## TL;DR

- **是什么**：把 NCSoft 5.8 真端的网络协议 + 1314 个 PL/pgSQL 存储过程 + 战斗副本任务等业务，
  在自有 Go runtime + Lua 脚本沙盒上重建出来。**不是逆向魔改**，是参考真端协议的全新实现。
- **为什么**：真端魔改天花板约 30%；自写可冲到 ~85%，是"高熵 AION 私服"命题的载体（详见
  上层 `../CLAUDE.md` 战略文档）。
- **本目录范围**：服务端代码 + 配置 + 脚本 + 工具 + 文档。客户端在 `../client/`，归档 C++/Rust
  实现在 `../../_archive/`。

---

## 当前状态

> 截至本文档生成日期 **2026-05-05**（不是"目前"——避免快速过时；以
> `git log --oneline -10` 为准）。

| 维度 | 状态 |
|------|------|
| Go 进程拓扑 | gateway / world / chat / logd / admin（5 进程，二进制全部 < 30MB） |
| Lua 业务脚本 | 87+ 文件，覆盖 handlers / skills / events / instances / npcs / quests |
| Go 测试 | `make test` 通过（基线 340+ tests，详见最新 commit message） |
| 协议 crypto | Blowfish-LE / RSA-1024 / XOR(seed=1234) 全部端到端验证 |
| PG 存储过程 | 移植已起步（`sql/schema/*.sql`）；目标 1314 个，详见 Q1 计划 |
| 副本系统 | S-19 MVP 落地（Haramel + Beshmundir 两张图） |
| Entropy 系统 | v0/v1 hooked（`entropy.forge_id` / `add_item_with_random_attr`），等 PG SP B 轨补齐 |

---

## 三层架构

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1 ── Go Runtime（薄；几乎不动）                        │
│  网络 I/O · 包编解码 · BF-LE/RSA/XOR · pgx 池 · gopher-lua    │
│  ECS · Redis 客户端 · NATS 客户端 · TOML 配置 · 结构化日志     │
└─────────────────────────────────────────────────────────────┘
                              ↓ 暴露全局函数
┌─────────────────────────────────────────────────────────────┐
│  Layer 2 ── Lua Scripts（厚；天天动；1 秒热重载）              │
│  scripts/handlers/ · scripts/skills/ · scripts/combat/        │
│  scripts/ai/ · scripts/quests/ · scripts/events/              │
│  scripts/instances/ · scripts/npcs/ · scripts/lib/            │
└─────────────────────────────────────────────────────────────┘
                              ↓ 通过 db.call("aion_xxx", ...)
┌─────────────────────────────────────────────────────────────┐
│  Layer 3 ── PostgreSQL Stored Procedures（稳；改得最少）       │
│  ~1314 个 PL/pgSQL 函数 · 业务原子操作 · 数据完整性 · 事务      │
└─────────────────────────────────────────────────────────────┘
```

数据通路：

```
5.8 Client ── TCP ──▶ gateway :2108/:7777 ── BF/XOR 解密
                              │
                              ▼ NATS JetStream events
                       world (ECS + Lua VM)
                              │
                              ├─▶ db.call("aion_xxx") ─▶ PostgreSQL
                              ├─▶ Redis（session / 在线状态）
                              └─▶ jobq（定时副本到期 / 拍卖结算）
```

---

## 启动命令速查

```bash
# 一次性：编译 5 个进程到 ./bin/
make build

# 启动中间件 + 5 进程，再跑 tinyclient 端到端验证（最常用）
make boot-test

# 仅启动（不跑 client）
make boot

# 全停（保留 PostgreSQL 服务，仅停 nats / devredis / 5 个 .exe）
make stop

# 跑测试 / 静态检查 / coverage / 微基准（与 CI 等价）
make lint
make test
make cover
make bench
```

环境变量：
- `AIONCORE_DB_PASS` — PG 密码（默认 `postgres`）
- `AIONCORE_CONFIG_DIR` — TOML 配置目录（Makefile 自动指向 `./config/`）

---

## 文档地图

### 入口（先看这两个）

| 文档 | 内容 |
|------|------|
| [`CLAUDE.md`](./CLAUDE.md) | AI 协作 / 编码铁律 / 服务表 / 路径锚 |
| [`doc/dev-guide.md`](./doc/dev-guide.md) | **Source of Truth**：三层职责 + Go/Lua 规范 + 反模式 |

### 架构 / 协议 / API

| 文档 | 内容 |
|------|------|
| [`doc/architecture.md`](./doc/architecture.md) | 进程拓扑 · 数据流 · 持久化策略 · 热加载边界 · 测试金字塔 |
| [`doc/opcodes.md`](./doc/opcodes.md) | CM_*/SM_* 全 opcode 表 + 已分配/保留范围 |
| [`doc/lua-api.md`](./doc/lua-api.md) | Bridge 注入的所有 Lua 全局（log/db/entity/player/world/combat/bytes/jobq/entropy/config）+ 沙盒策略 |

### 工程化

| 文档 | 内容 |
|------|------|
| [`doc/ci.md`](./doc/ci.md) | GitHub Actions 流水线 + 本地 `make` 等价目标 |
| [`doc/observability.md`](./doc/observability.md) | 结构化日志 · metrics · trace |
| [`doc/coverage.md`](./doc/coverage.md) | 覆盖率基线 + 推进策略 |
| [`doc/benchmarks.md`](./doc/benchmarks.md) | crypto / luahost / database 微基准 |
| [`doc/dev-boot-checklist.md`](./doc/dev-boot-checklist.md) | 首次开机 PG / NATS / Redis 准备清单 |

### 移植 / 库存

| 文档 | 内容 |
|------|------|
| [`doc/s18-sp-inventory.md`](./doc/s18-sp-inventory.md) | NCSoft → PG SP 移植清单（S-18 mail/warehouse 阶段） |
| [`doc/s18-nats-inventory.md`](./doc/s18-nats-inventory.md) | NATS subject 命名清单 |
| [`doc/migration/`](./doc/migration/) | NCSoft SQL Server → PG 迁移工具 + schema dumps |

---

## 编码铁律 (摘自 [`doc/dev-guide.md`](./doc/dev-guide.md))

> 违反任何一条都会产生 bug，且大概率不会立刻暴露。

1. **业务逻辑只能调 PG SP** — 1314 个 PL/pgSQL 函数 *是* 业务逻辑。Go 和 Lua 都不准写
   裸 `INSERT/UPDATE/DELETE`。
2. **游戏逻辑必须在 Lua** — Go 只做 network / ECS / DB pool / Lua VM host。
   战斗 / 技能 / 任务 / 副本写在 Go 里 = 走错层。
3. **PostgreSQL 仅监听 127.0.0.1** — 2026-04-11 勒索事件教训，不要再讨论开远程。
4. **不要硬编码** — 端口 / rate / 副本参数全部走 TOML 或 PG。
5. **Blowfish 是小端** — NCSoft 非标准。Go 标准库 `crypto/blowfish` 是大端，**不能用**。
   走 `internal/crypto/blowfish_le.go`。
6. **账号名 ≤ 17 字符** — RSA-1024 凭据块大小硬限。
7. **XOR 顺序：XOR-first, ADD-stored, seed = 1234** — AL-Login 的反向顺序会污染会话密钥。
8. **5.8 客户端会忽略 XOR 校验位** — 即使校验失败也要接收数据，不能丢包。
9. **scripts/ 全程热重载** — 不要写持久 closure / 全局表；状态放 ECS 组件。
10. **测试隔离** — `internal/...` 每个包都要有 `_test.go`；新功能走 TDD：写复现 → 红 →
    实现 → 绿 → 重构。

---

## 数据库

四个 PG 库，全部仅 `127.0.0.1`：

| 库名 | 用途 | SP 数（NCSoft 真端） |
|------|------|----------------------|
| `aion_world_live` | 角色 / 物品 / 公会 / 副本 / 拍卖 | ~1063 |
| `aion_account_db` | 账号认证 | ~52 |
| `aion_account_cache_db` | 会话缓存 / 排行榜 | ~101 |
| `aion_gm` | GM 工具 | ~183 |

---

## 法律边界

1. NCSoft 5.8 客户端二进制 = NCSoft 版权 → 国内商运灰色，仅 QQ 群 1-100 朋友自玩，**不收费**。
2. 自写服务端代码 = 本仓库版权所有；可参考 NCSoft 协议但不能照搬其代码。
3. 玩家协议必须明示反外挂 / 行为采集范围（详见 `tools/ShiguangGate-v1/CLAUDE.md`）。

---

## 子目录速查

```
server/
├── src/internal/        Go 私有包
│   ├── aionproto/         AION 包编解码 + opcode 常量
│   ├── crypto/            BF-LE / RSA / XOR
│   ├── database/          pgx 池 + SP caller
│   ├── luahost/           gopher-lua VM 池 + bridge.go(Go→Lua API)
│   ├── ecs/               实体-组件-系统
│   ├── jobq/              异步任务队列（asynq + Redis）
│   ├── ipc/               NATS 客户端封装
│   ├── config/            TOML 加载 + fsnotify 热重载
│   ├── session/           会话管理
│   ├── telemetry/         结构化日志 + metrics
│   ├── persona/           NPC 性格 / AI prompt
│   ├── memory/            会话记忆 / Redis cache
│   ├── spsynth/           PG SP 合成生成器（实验）
│   └── director/          副本/世界事件总线（实验）
├── src/cmd/             5 个生产进程 + 实验 + 测试客户端
│   ├── gateway/   world/   chat/   logd/   admin/
│   ├── tinyclient/        端到端 smoke 客户端
│   ├── spike/             实验入口
│   └── director/          实验入口
├── scripts/             Lua 业务（热重载）
│   ├── handlers/   skills/   combat/   ai/   events/
│   ├── quests/   instances/   npcs/   data/
│   └── lib/               共享：mail/warehouse/auction/group/legion/instance/...
├── sql/schema/          PG schema + SP 定义（goose 迁移）
├── config/              TOML 配置（gateway/world/chat/...）
├── doc/                 本文档地图所列文件
├── tools/               devredis / version-dll / monono2 等
├── lua/                 gopher-lua 拷贝 / 兼容垫片
└── bin/                 编译产物（.gitignore）
```

---

## 相关链接

- 上层战略：[`../../CLAUDE.md`](../../CLAUDE.md)（拾光AI 主仓 README）+
  `../../doc/business/guanghui-yongheng-roadmap-20260425.md`（高熵 roadmap）
- 客户端目录：[`../client/`](../client/)（35 GB，read-only）
- 归档参考：`../../_archive/aioncore-cpp-20260412.tar.gz`（C++20 旧实现，BF/RSA 验证用）
- 4.8 平行实验场：[`../../BEY_4.8/`](../../BEY_4.8/)（Java，独立工作区）

---

*本文档面向 future contributor / future-claude；如有结构变更，请同步 `CLAUDE.md` 与本文。*
