# ADR-0007: Lua 热重载 / Go 重启 / SP 直换 — 三种变更模式

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

AionCore 三层架构（见 ADR-0001）下，不同层的"变更频率"差几个量级：

| 层 | 典型变更 | 频率 |
|----|---------|------|
| Go (Layer 1) | 加 opcode 常量 / 改 ECS 组件 shape / 修 crypto bug | 月级 |
| Lua (Layer 2) | 改技能数值 / 改任务流 / 加 NPC 对话 / 改副本规则 | 日级 / 小时级 |
| PG SP (Layer 3) | 加新 SP / 修补 race / 调字段约束 | 周级 |

游戏服务器的"业务规则迭代极快"和"运行时极度稳定"是冲突的需求。如果所有变更都
要重启进程，业务节奏跟不上；如果让 Go 也热替换（用 `plugin` 包），跨平台破裂
（Windows 不支持，且加载顺序 / 类型一致性极脆），还会牺牲编译期类型安全。

我们必须在三层之间各自选择"变更如何生效"的机制，并把选择固化为约束。

## 决策 (Decision)

我们采用三种独立的变更模式，按层强绑定：

### Lua（Layer 2）— `fsnotify` 热重载，≤1 秒生效

- `scripts/**/*.lua` 改动后 `internal/luahost/` 监听文件变动
- 整个 VM 池原子 swap：新 VM 加载新脚本，旧 VM 排空已在飞的请求
- **不需要重启 world 进程**
- 生产 1s 节流；dev 0.5s 节流（详见 `prod/config/world.toml` vs `dev/config/world.toml`）

### TOML 配置 — `fsnotify` 热重载，秒级生效

- `config/*.toml` 改动后 `internal/config/` 监听
- Lua 通过 `config.rates(...)` / `config.get(...)` 读
- **不需要重启**
- 例外：`gateway.toml` 的端口 / DB 连接串等启动期消费的字段不重读，要改必须重启

### PG SP（Layer 3）— `psql` 直接 `CREATE OR REPLACE FUNCTION`，无锁

- PG 函数重定义不锁表，对在飞事务影响极小
- `embedded goose` 迁移在进程启动时跑；运维期可直接 `psql` 替换
- **不需要重启**
- 例外：表结构变更（`ALTER TABLE`）按 PG 规则锁；这种变更要走维护窗口

### Go（Layer 1）— **必须重启**进程

- `go build ./cmd/... && make stop && make boot`
- 没有 `plugin` 机制（跨平台 + 类型安全 + 易出错）
- 例外：opcode 常量（`internal/aionproto/opcodes.go`） / ECS Component shape /
  crypto / NATS subject 名 — 全部要重启
- 重启时间目标 < 30 秒（5 进程并行 boot），玩家断线一次

辅助约束：

- **Lua 不写持久 closure / 长 timer**：状态放 ECS 或 Redis，否则热重载丢状态
- **Lua 每个文件 `return table` 形态**：不污染 global namespace，便于整池替换
- **opcode 是 Go 常量不是 Lua 常量**：opcode 改了协议层都得改，必须强约束 + 编译期

## 后果 (Consequences)

### 正面 (Positive)

- 业务迭代极快：90% 的策划改动 1 秒生效
- Go 编译期类型安全完整保留
- Lua 错误天然 sandbox：runtime panic 不拖死进程，只丢一个请求
- 配置 / 数据 / 业务三种热替换模式覆盖 95% 的变更场景
- 双重心智模型清晰："改 .lua 就生效；改 .go 要重启" — 一句话能讲清

### 负面 (Negative)

- Lua 错误**运行时才暴露**：拼写错的字段 / 调错 API 在第一次跑到才崩
  → 必须配 luahost 集成测试 + lint
- Lua 没有强类型：要靠 `lua-api.md` 当事实文档兜底
- 心智模型双轨：新人要学"哪些改动属于 Layer 1 必须重启" — 文档反复强调
- 热重载窗口期可能丢请求：旧 VM 排空不及时的极端情况下，1-2 个请求可能 panic
  →fallback 是丢 + log，非崩溃

### 中性 / 影响 (Neutral)

- 测试金字塔自然分裂：Go 单测 / Lua VM 集成测试 / PG SP 集成测试 / E2E boot-test
  四层
- 部署流水线只编译 Go：Lua / SP / TOML 直接同步即可
- 监控要分层：Go panic 看 slog；Lua error 看 luahost log；SP error 看 PG log

## 备选方案 (Alternatives Considered)

- **Go `plugin` 包做 Layer 1 热替换**：
  - 否 — Windows 不支持；类型一致性脆（一个老 plugin 持有的旧类型实例与新加载的
    新类型不兼容，会 runtime panic）
  - 维护负担远大于收益
- **全部走配置 / DSL**（业务逻辑用 YAML / DSL）：
  - 否 — 业务逻辑配置化是反模式；技能 / 副本 / 任务里的分支太多，写配置比写
    Lua 更难维护
- **全部静态编译**（C++ / Rust 风格）：
  - 否 — 见 ADR-0001；归档的 C++20 版已证明这条路慢
- **单一 Lua 文件 monolith + 部分 require**：
  - 否 — 热重载粒度太大，修一个 skill 重载全部
- **embed Lua 到 Go binary**：
  - 否 — 与"业务规则文件级独立"冲突；运维不能直接 `vim scripts/skills/skill_1001.lua`
- **每次 Lua 改动重启进程**：
  - 否 — 30 秒重启 × 一日数十次改动 = 玩家天天断线，体验崩
- **Erlang / OTP hot code swap**：
  - 否 — 见 ADR-0001；语言生态不够 + 团队规模 1 人
- **JS / V8 热替换**：
  - 否 — V8 内嵌 Go 不成熟；Lua 在 AION 生态有先例

## 引用 (References)

- `server/CLAUDE.md` — Configuration / Hot-reloadable
- `server/doc/architecture.md` §6 热加载边界 / §5 状态持久化
- `server/doc/dev-guide.md` §3 Lua 脚本规范（"Hot-reload safe" 约束）
- `src/internal/luahost/` — VM 池 + bridge + reload
- `src/internal/config/` — TOML fsnotify 热重载
- `prod/config/world.toml` vs `dev/config/world.toml` — 1s vs 0.5s 节流差异
- `ACE_5.8/CLAUDE.md` — Prod vs Dev Quick Reference 表
- commit `4a684ac` 初始 Phase S-0 ~ S-17（含 luahost VM 池实现）
