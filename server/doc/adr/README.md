# Architecture Decision Records (ADR)

## 这是什么 / What this is

ADR（Architecture Decision Record，架构决策记录）用于固化"我们为什么这样选"的工程
事实，让 6 个月后的人 / 新贡献者 / future-claude 不必从代码逆推决策。每篇 ADR 解决
一个"如果不知道这个决策，下一个修改者会破坏什么"的问题。

格式遵循 Michael Nygard 经典模板（2011，"Documenting Architecture Decisions"），见
本文末。

## 为什么用 / Why

AionCore 5.8 是把 NCSoft 的 1314 个 PL/pgSQL SP + 自研 BF-LE crypto + Go 瘦运行时 +
Lua 业务逻辑捏在一起的"非标准"游戏服务器。它的每一个非标选择背后都有一个具体的
约束（兼容性 / 性能 / 热重载 / 团队规模）。如果不写下来，下一个修改者就会"顺手"把
它改回标准做法，然后客户端连不上 / 业务逻辑动不了。

## 流程 / Process

1. **提案 (Proposed)**：在 `doc/adr/NNNN-slug.md` 落初稿，状态写 `Proposed`
2. **讨论 (Discussion)**：commit 上去走 PR review；任何人可质疑
3. **决策 (Accepted)**：合入主线后状态改 `Accepted`，记录决策日期与决策者
4. **入仓 (In repo)**：永远在 git 里；后续被新决策推翻只能 `Superseded by ADR-XXXX`
5. **不删除**：被推翻的 ADR 仍保留 — 历史是"我们当时为什么是对的"的最强证据

## 编号约定 / Numbering

- 4 位数 zero-padded（`0001`, `0002`, …, `9999`），单调递增，绝不复用
- 文件名 `NNNN-kebab-case-slug.md`
- ADR 编号在 git 历史中是不可变的；即使被 superseded 也不重号

## 当前 ADR 列表 / Current Index

| # | Title | Status | Date |
|---|-------|--------|------|
| [0001](./0001-go-lua-split.md) | Go + Lua + PG SP 三层架构分离 | Accepted | 2026-04-12 |
| [0002](./0002-blowfish-little-endian.md) | Blowfish 小端非标准实现 | Accepted | 2026-04-12 |
| [0003](./0003-all-sql-via-sp.md) | 所有 SQL 走 PostgreSQL 存储过程 | Accepted | 2026-04-12 |
| [0004](./0004-ecs-entity-model.md) | ECS（Entity-Component-System）实体模型 | Accepted | 2026-04-12 |
| [0005](./0005-nats-jetstream-ipc.md) | 进程间通信用 NATS JetStream | Accepted | 2026-04-12 |
| [0006](./0006-river-asynq-dual-queue.md) | river + asynq 双引擎任务队列 | Accepted | 2026-04-26 |
| [0007](./0007-lua-hot-reload-go-restart.md) | Lua 热重载 / Go 重启 / SP 直换 | Accepted | 2026-04-12 |

状态枚举：

- `Proposed` — 初稿讨论中
- `Accepted` — 已合入并视为约束
- `Deprecated` — 不推荐但还在用
- `Superseded by ADR-XXXX` — 被新 ADR 替代，保留备查

---

## 模板 / Template (Michael Nygard)

新增 ADR 时，复制下面骨架：

````markdown
# ADR-NNNN: <Title>

- 状态 (Status): Accepted / Proposed / Deprecated / Superseded by ADR-XXXX
- 日期 (Date): YYYY-MM-DD
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

<问题是什么？什么力量推动我们要做这个选择？技术 / 业务 / 团队 / 历史约束都列上。>

## 决策 (Decision)

<我们决定做什么。第一句话是行动语句 ("我们采用 X")。后面再展开理由。>

## 后果 (Consequences)

- 正面 (Positive)：<好处 1 / 好处 2>
- 负面 (Negative)：<代价 1 / 代价 2>
- 中性 / 影响 (Neutral)：<架构上的连带影响>

## 备选方案 (Alternatives Considered)

- **方案 A**：<是什么> — 为什么否
- **方案 B**：<是什么> — 为什么否

## 引用 (References)

- commit / phase / 文档 / 外部资料
````

---

## 写作守则 / Writing rules

1. **描述性，不情绪化**：说"我们采用 X 因为 Y"，不说"X 是更优雅的方案"
2. **第一句话是行动**：决策段开头一句必须能独立回答"做了什么"
3. **备选至少 2 个**：单一方案不是决策，是默认；至少列两个并写为什么否
4. **引用必须真**：commit hash / 文档路径 / 外部 URL — 编造一律不行
5. **80-200 行**：篇幅短到能 5 分钟看完，长到承得住 6 个月后追问
6. **术语用英文标题**（Status / Decision / Consequences / Alternatives），正文中文 OK

## 何时不写 ADR / When NOT to write one

- 修 bug（除非引入新约束）
- 加单个 handler / skill / quest（属于 Layer 2 业务，常态变更）
- 调整 TOML 配置 / 加测试用例
- 重命名 / 整理代码风格

写 ADR 的判断标准：**"如果不知道这个决策，下一个修改者会破坏什么？"** 答得上来就写。
