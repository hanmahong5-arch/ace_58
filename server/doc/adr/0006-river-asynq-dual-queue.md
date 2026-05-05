# ADR-0006: river + asynq 双引擎任务队列

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-26
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

S-13 起 AionCore 引入持久后台任务（async job queue），覆盖以下用例：

1. **邮件投递**（`MailDeliverArgs`）：玩家给离线玩家发邮件，要保证 commit 后再投递；
   投递失败要重试；与发件人 SP 必须**同事务**（避免发件人物品被扣但邮件没发出）
2. **拍卖到期**（auction expire）：拍卖结束触发结算 SP；不能丢
3. **副本到期**（instance expire）：副本运行 N 小时后失效，触发清理
4. **每日重置**（`KindDailyReset`）：cron 表达式 `0 9 * * *`（北京 9 点）批量重置
   每日任务 / 副本 cooldown
5. **世界 boss 刷新**：cron 调度 + 抗错重试
6. **Lua 业务发起的延迟任务**：Lua handler 想"5 秒后给玩家发信" / "10 分钟后清场"

要求矩阵：

| 用例 | 与 SP 同事务 | cron 调度 | 持久化 | 重试 |
|------|-------------|-----------|--------|------|
| 邮件投递 | 必须 | 否 | 必须 | 必须 |
| 拍卖到期 | 必须 | 否 | 必须 | 必须 |
| 每日重置 | 不要求 | 必须 | 必须 | 必须 |
| Lua 延迟任务 | 不要求 | 否（一次性 delay） | 必须 | 必须 |

**没有任何单一开源队列同时满足"PG 事务集成"和"cron 调度"两个维度**：

- `riverqueue/river`：PG SKIP LOCKED + 事务型 enqueue（`river.Insert(tx, args)` 与
  业务 SP 在同一笔 PG 事务里 commit），但 cron 弱（rivermigrate 只有迁移工具，
  rivercron 是商业付费产品）
- `hibiken/asynq`：Redis 后端 + cron 表达式调度 + 优先级队列，但**不能与 PG 事务
  原子绑定**

## 决策 (Decision)

我们采用 river + asynq 双引擎，按用例特性路由：

- **river（PG SKIP LOCKED 事务型）**：邮件投递 / 拍卖到期 / 副本到期 — 所有"必须
  与业务 SP 同事务"的任务
  - 入口：`internal/jobq/bundle.go` 包装；当 PG pool 提供时启用
  - JobArgs：`MailDeliverArgs`（典型示例，见 `args.go`）
  - 工作模式：worker pool 在 world 进程内
- **asynq（Redis cron / 调度型）**：每日重置 / 世界 boss 刷新 / Lua 发起的延迟任务
  - 入口：同 `internal/jobq/bundle.go`；当 Redis 可用时启用
  - 任务种类：`KindDailyReset` 等
  - 工作模式：可选独立 asynq server worker
- **降级**：无 PG pool → river 禁用；无 Redis → asynq 禁用；都没 → jobq 整个 no-op
  （单测 / 最小启动友好）
- **Lua 桥**：`luahost.Bridge` 注入的 `jobq.*` 全部走 asynq —— Lua 不直接看 river
  （river 强类型 JobArgs 需要 Go 编译期注册，与 Lua 热重载冲突）

## 后果 (Consequences)

### 正面 (Positive)

- 事务型任务（邮件 / 拍卖）的 commit / rollback 与业务 SP 完全一致
  （river.Insert 共享同一笔 `pgx.Tx`）
- cron 表达式靠 asynq 解决（`0 9 * * *` 这种写法直接可用）
- 双引擎都成熟（river: Brandur Leach 主导；asynq: Hibiken / Anki 维护）
- jobq facade 把双引擎差异封死：调用方只看 `jobq.Enqueue / Schedule`
- 降级路径完整：开发 / 单测可以零中间件起进程

### 负面 (Negative)

- 维护两套 worker pool / 两套监控指标 / 两套配置
- 心智成本：什么任务走哪个？ — 靠 `bundle.go` 文件头注释 + 命名约定（`*Args` 走
  river，`Kind*` 走 asynq）兜
- river worker 强类型注册要 Go 编译期；新增事务型任务要重启进程
- Lua 只能用 asynq 子集，碰到"邮件投递与 SP 同事务"这种场景必须走 Go handler
  （而不是 Lua 直接发起）

### 中性 / 影响 (Neutral)

- 双引擎都用 PG / Redis 持久化，进程重启后任务续跑 — 不丢
- river 的 SKIP LOCKED 与 asynq 的 Redis BLPOP 互不干扰，可同进程跑
- 监控接两套：river 自带 dashboard endpoint；asynq 有 asynqmon

## 备选方案 (Alternatives Considered)

- **单 river**：
  - 否 — cron 调度弱（rivercron 商业付费，开源版只有迁移）
  - 每日重置 / 世界 boss 刷新没法优雅写
- **单 asynq**：
  - 否 — 没法与 PG 事务原子绑定；邮件 / 拍卖会出"SP commit 但任务丢" / "SP 回滚
    但任务跑了"两类 race
- **自写**（PG NOTIFY / LISTEN + cron 表达式）：
  - 否 — SKIP LOCKED 正确实现 / 重试 / dead letter / dashboard 全要重做
  - 路线 1（river）已经成熟，自写没收益
- **Temporal / Cadence**：
  - 否 — 工作流引擎过度工程；学习曲线高；额外 4-6 个进程
- **Sidekiq / Resque**（Ruby）跨语言调度器：
  - 否 — 不想引入第二运行时
- **PostgreSQL pg_cron**：
  - 否 — 需要 superuser 权限；扩展安装在国内 PG 部署（含一些云厂商）受限
  - 不能与应用层重试逻辑共享代码

## 引用 (References)

- `src/internal/jobq/bundle.go` — facade 实现 + 文档注释
- `src/internal/jobq/args.go` — `MailDeliverArgs` 等 river JobArgs
- `src/internal/jobq/workers.go` — `KindDailyReset` 等 asynq kind 注册
- `src/internal/jobq/bundle_test.go` / `workers_test.go` — 单测
- `server/doc/architecture.md` §5 状态持久化 / §0 world 进程 jobq
- riverqueue/river：https://github.com/riverqueue/river
- hibiken/asynq：https://github.com/hibiken/asynq
- commit `08fda85` phase S-18: auction settlement + system mail rewire
- commit `5d23478` phase S-19: instance/dungeon MVP + jobq expiry + daily reset
