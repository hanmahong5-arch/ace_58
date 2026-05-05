# ADR-0005: 进程间通信用 NATS JetStream

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

AionCore 拓扑是 5 个进程：

| 进程 | 端口 | 职责 |
|------|------|------|
| gateway | 2108 / 7777 | 协议编解码 / 握手 / 转发 |
| world | — | ECS + Lua VM + 业务 |
| chat | 10241 | 频道聊天 |
| logd | — | 异步日志 → ClickHouse |
| admin | 8080 | REST + dashboard |

它们之间需要可靠事件总线：

1. **gateway → world**：玩家进入 / 退出 / 包到达事件（`player.enter` /
   `player.leave` / `player.cm_*`）
2. **world → gateway**：把 SM_* 包按 gw_seq_id 推回对应连接（`gw.sm.*` 之类的
   subject）
3. **world → chat**：广播 / 公会聊天事件
4. **world → logd**：玩家操作 / 战斗结算日志
5. **admin → world**：GM 命令下发

需求：

- **subject-based 路由**：单进程横向扩展时，多 world worker 按 player_id hash 分发
- **at-least-once + 持久化**：包丢了游戏体验崩
- **能优雅降级**：开发期 / 单测期不想起 NATS，要有 NilClient
- **成熟可运维**：单二进制 / 无依赖 / 中文社区有人

## 决策 (Decision)

我们采用 NATS JetStream 作为主进程间通信总线（`src/internal/ipc/`，依赖
`github.com/nats-io/nats.go`），并通过 `NewNilClient()` 提供静默降级模式。

约定：

- **Subject 命名空间**（详见 `doc/s18-nats-inventory.md`）：
  - `player.enter` / `player.leave` / `player.cm_<opcode>`
  - `gw.sm.<gw_seq_id>` — gateway 下行
  - `chat.broadcast.*` / `chat.guild.*`
  - `logd.event.*`
  - `admin.cmd.*`
- **持久化**：JetStream stream 配 file storage，断电不丢
- **降级**：单测 / 单进程 boot 用 `ipc.NewNilClient()`，所有 Publish/Subscribe
  变 no-op
- **运维**：`make boot` 自动起 `nats-server.exe`（`~/go/bin/`），
  `make stop` 关停
- **核心 NATS（非 JetStream）作为 fallback**：低优先级 fire-and-forget
  事件可走核心 NATS（不持久），关键路径必走 JetStream

## 后果 (Consequences)

### 正面 (Positive)

- subject 路由 + at-least-once + 持久化一站式解决
- NilClient 让单测 / 单进程 dev 不需要起额外中间件
- nats-server 是单 Go 二进制，部署 0 摩擦（vs Kafka 要 ZK / KRaft）
- 5.8 真服 6 玩家级别完全够，未来扩到 30+ MAU 也不会瓶颈
- 跨进程拓扑灵活：未来加 director / persona / memory 进程不需要改协议

### 负面 (Negative)

- 多一个进程要维护（boot / 监控 / 升级）
- JetStream 单点：单 nats-server 节点挂了所有 IPC 停摆
  （未来需要 cluster 时要专门规划）
- subject 名是字符串约定，typo 会静默失败 — 必须有 `s18-nats-inventory.md`
  这种事实清单 + 测试覆盖
- NATS 客户端发布 / 订阅模式与 gRPC 风格 RPC 不同，新人需要心智切换

### 中性 / 影响 (Neutral)

- 启动顺序约束：nats-server 必须先于 gateway / world 启动（Makefile 已处理）
- 包大小 limit：JetStream 默认 1MB；AION 包通常 < 4KB，无问题
- observability：JetStream 自带 metrics endpoint，接 Prometheus 即可

## 备选方案 (Alternatives Considered)

- **gRPC streaming**：
  - 否 — 状态化连接 + 重连复杂；多 world worker 时按 player_id 路由要在客户端实现
  - 协议 schema (proto) 给 Lua 桥接增加摩擦
- **Redis Pub/Sub**：
  - 否 — 不持久化（断电丢消息）；at-most-once 不够
  - Redis Streams 有持久化但 consumer group 用起来比 JetStream 复杂
- **Apache Kafka**：
  - 否 — 重（JVM + ZooKeeper / KRaft）；单 partition 性能反而比 NATS 低
  - 我们是低 QPS（< 1000 msg/s）场景，Kafka 杀鸡用牛刀
- **自写 TCP IPC（继承 NCSoft 老路）**：
  - 否 — 踩 18 年的坑等于把 NCSoft 自己的事故再踩一遍
  - 自写 = 重连 / 心跳 / 序列化都要做，没收益
- **RabbitMQ / ActiveMQ**：
  - 否 — Erlang / Java 运行时比 NATS 重一个数量级
- **进程内 channel / 单进程**：
  - 否 — gateway 解 BF-LE 是 CPU 密集；与 world 的 ECS / Lua VM 单线程冲突
  - 5 进程拆分本身是 ADR-0001 三层架构的延伸

## 引用 (References)

- `src/internal/ipc/nats.go` — 客户端封装 + NilClient
- `src/internal/ipc/events.go` — subject 常量
- `src/internal/ipc/nats_smoke_test.go` — 集成测试
- `server/doc/architecture.md` §0 / §2 / §9
- `server/doc/s18-nats-inventory.md` — subject inventory（事实文档）
- `server/CLAUDE.md` — `nats-server.exe` 由 Makefile boot 启动
- commit `abaa3b1` Round-10 F4: 5 进程拓扑端到端 boot-test 落地
