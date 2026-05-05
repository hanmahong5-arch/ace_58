# ADR-0001: Go + Lua + PG SP 三层架构分离

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

AionCore 5.8 是 NCSoft AION 5.8 私服的自写实现，要同时满足：

1. **业务规则迭代极快**：技能数值 / 副本掉率 / NPC 对话 / 任务节点几乎日级变动；
   要求"改完 1 秒生效"，不能停服编译。
2. **网络层延迟敏感**：Blowfish-LE / RSA / XOR 解密在 7777 端口高频热路径上跑；
   一次 GC 抖动可能让一票玩家瞬移。
3. **数据原子性极强**：1314 个 NCSoft T-SQL SP 已被移植到 PG，事务边界 / 防回滚
   逻辑都固化在 SP 里。复刻或绕过这些 SP 都会重新引入 18 年线上的 bug。
4. **团队极小**（~1 个全职 + AI 协作）：单语言全栈是不现实的负担分布。
5. **C++20 前驱归档**：早期 `_archive/aioncore-cpp-20260412.tar.gz` 用纯 C++20 写
   过一版，证明"网络 + 业务全 C++"的迭代速度跟不上需求。

不解决这个问题，我们要么"业务每改一行都重启 + 编译 30 秒"，要么"性能塌方"。

## 决策 (Decision)

我们采用 Go (Layer 1) + Lua (Layer 2) + PostgreSQL SP (Layer 3) 的三层强分离架构，
并以"代码出现在哪一层"作为不可让步的硬约束：

- **Layer 1 — Go 瘦运行时**（约 10% 代码量，月级变更）：
  - TCP server / 包帧 / Blowfish-LE / RSA / XOR
  - pgx 连接池 / NATS 客户端 / Redis 客户端
  - ECS 框架 / gopher-lua VM 池 / `luahost.Bridge` 注入器
  - jobq（river + asynq）/ telemetry / config 热重载
  - **绝不写业务逻辑**

- **Layer 2 — Lua 业务**（约 85% 代码量，日级 / 小时级变更，热重载 ≤1s）：
  - `scripts/handlers/cm_*.lua` — 所有 packet handler
  - `scripts/skills/skill_*.lua` — 技能效果
  - `scripts/combat/*.lua` — 战斗 / 伤害公式
  - `scripts/ai/*.lua` — NPC 行为
  - `scripts/quests/quest_*.lua` — 任务状态机
  - `scripts/events/on_*.lua` — 事件回调
  - `scripts/instances/inst_*.lua` — 副本

- **Layer 3 — PG PL/pgSQL SP**（约 5% 代码量，周级变更，`psql` 直接替换函数）：
  - 1314 个 NCSoft 移植 SP，覆盖角色 / 物品 / 邮件 / 拍卖 / 副本 cooldown / 公会
  - **唯一允许写裸 SQL 的地方**

铁律：**Go 永远不调 SQL；Lua 永远不调 SQL；业务逻辑永远不进 Go**。

## 后果 (Consequences)

### 正面 (Positive)

- 业务热重载 ≤1 秒生效，不停服上线（`fsnotify` 监听 `scripts/`）
- Go 层窄到 ~10% 代码量，类型安全保留在最热路径上
- Lua 错误天然 sandbox（panic 不会拖死 world 进程，只丢一个请求）
- token 成本符合 90/10 分布：Layer 2 改一处 ~500 token，Layer 1 改一处 ~3000 token
- 测试金字塔自然成形：crypto / aionproto 单测 + luahost VM 测试 + database 集成测试

### 负面 (Negative)

- 三语言栈的学习曲线（Go + Lua + PL/pgSQL），新人上手慢
- Go-Lua 桥（`internal/luahost/bridge.go`）需要精心设计，错一个 self 参数就崩
- Lua 5.1 (gopher-lua) 没有 LuaJIT 性能，热点函数要走 Go 实现
- 调试要懂三层：Go panic / Lua traceback / PG NOTICE 都要会看

### 中性 / 影响 (Neutral)

- 必须严格遵守"哪一层做什么"的边界，否则架构会塌
- 文档量大（每层一个 dev guide）
- IDE 支持 Lua 不如 Go，要靠 `lua-api.md` 当事实文档

## 备选方案 (Alternatives Considered)

- **纯 Go 单语言**（C++20 归档版的等价物）：
  - 否 — 业务每改一行就要 `go build` + 重启进程，热重载弱
  - Go plugin 机制跨平台破裂（Windows 不支持），不能救
- **纯 Lua / OpenResty 风格**：
  - 否 — Lua 没有原生 goroutine / channel，不适合写 ECS + NATS subscriber
  - 性能瓶颈在 BF-LE / RSA 解密上，Lua 跑不过 Go
- **Go + JavaScript via Goja**：
  - 否 — JS 生态对游戏服务器没有积累；gopher-lua 在 AION-Lua 真服已有先例
- **C++ 自带嵌入式脚本（Lua / Squirrel / ChaiScript）**：
  - 否 — C++ 版已在 2026-04-12 归档；C++20 的工程负担超过价值
- **Erlang/OTP**（理论上最适合游戏服务器）：
  - 否 — 团队规模 1 人 + AI；Erlang 学习曲线 + Aion 协议支持空白

## 引用 (References)

- `server/CLAUDE.md` — 三层架构 + 7 大铁律
- `server/doc/architecture.md` §1 三层职责矩阵
- `server/doc/dev-guide.md` §0 Golden Rules
- commit `4a684ac` — `init: AionCore 5.8 — Go+Lua AION game server (Phase S-0 ~ S-17)`
- 归档 C++ 实现：`_archive/aioncore-cpp-20260412.tar.gz`（pivot 为 Go+Lua 的同一周）
- 决策日志：`doc/business/decision-log-20260425.md`（D-list 项 D2 / D4）
- Michael Nygard, "Documenting Architecture Decisions", 2011
