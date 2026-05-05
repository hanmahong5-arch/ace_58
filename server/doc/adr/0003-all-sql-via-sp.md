# ADR-0003: 所有 SQL 走 PostgreSQL 存储过程

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

NCSoft AION 5.8 真服把几乎全部业务规则固化在 1395 个 T-SQL 存储过程里（dump 在
`ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/`）。这些 SP 包含：

- 18 年线上踩出来的所有 race / 死锁 / 防回滚补丁
- 物品 dup bug 修复（玩家用同一个物品同时换两笔、物品倒手时的事务保护）
- 邮件 / 拍卖 / 公会的离线状态机
- 副本 cooldown / 进度 / 重置规则
- 大量"看不出为什么必须这么写但删了就出 bug"的历史细节

我们的工程目标是 **把 1314 个 T-SQL SP 移植到 PG PL/pgSQL**（4 库分布：
`aion_world_live` ~1063 / `aion_account_db` ~52 / `aion_account_cache_db` ~101 /
`aion_gm` ~183），保留它们作为业务规则的唯一权威。

如果允许 Go 或 Lua 写 inline SQL，会出现：

1. **业务规则分散**：同一个"物品扣除 + 加另一物品"的事务可能在 Go 写一遍、Lua 写
   一遍、SP 写一遍，三处实现的 race 处理差异引入 dup bug
2. **NCSoft 历史漏洞复发**：18 年的补丁在 SP 里，绕过 SP 等于把这些补丁全扔了
3. **难以做高熵机制**：未来 modifier / affix 系统要原子地"读模板 → roll → 写实例"，
   在应用层做这件事 race 极难处理
4. **难以审计**：1314 个 SP 是一个有限集合，可以全文 grep；inline SQL 散在 Lua/Go
   里没法统一审计

## 决策 (Decision)

我们采用"所有 SQL 必须封装为 PG 存储过程"的硬约束，应用层只能调用 SP，不能写 inline
DML：

- **Go**：通过 `internal/database/CallSP()` 调用 SP，never 写 `INSERT/UPDATE/DELETE`
- **Lua**：通过 bridge 注入的 `db.call("aion_xxx", args...)` 调用 SP
- **新需求**：先在 `sql/schema/00NNN_xxx.sql` / `migrations/00NNN_xxx.sql` 加 SP，
  embedded goose 迁移上线，再让应用层调

允许的例外（非常窄）：

- **静态模板 SELECT**：启动时一次性把物品 / NPC / 技能模板灌入 ECS（"Jay Lee 模式"），
  这种纯读 + 一次性的查询可以走简单 `SELECT` 而非 SP
- **运维查询**：admin 进程的诊断只读 `SELECT` 可以 inline，但不能写

## 后果 (Consequences)

### 正面 (Positive)

- 业务规则集中在 PG 一处，全文 grep 即可审计
- 防 SQL injection：所有参数走 pgx 参数化，SP 内部用 `EXECUTE format()` 时也强约束
- 事务边界清晰：一个 SP = 一个原子单元，Go/Lua 调一次就是一笔事务
- NCSoft 18 年的历史补丁全部保留下来
- PG 函数热替换无锁（`CREATE OR REPLACE FUNCTION` 不锁表），SP 改动不需重启进程

### 负面 (Negative)

- 1314 个 SP 移植是大工程（Q1 主任务，按 Round 分批推进）
- T-SQL → PL/pgSQL 不是 1:1 映射（`@@IDENTITY` / `OUTPUT INSERTED` / 表变量都要重写）
- 调试需要 PG 客户端工具（DataGrip / pgAdmin / `psql`），不能只看 Go log
- 单测要起真 PG 容器（见 `internal/database/integration_test.go` + `database/README.md`）
- SP 没法享受 Go 类型安全 — 参数 / 返回类型靠约定 + 测试兜底

### 中性 / 影响 (Neutral)

- `internal/database/migrations/` 走 embedded goose；CI 跑 PG container 验证迁移
- 每个 SP 一个测试（见 `s14_test.go` / `s15_test.go` / `content_seed_test.go` 等）
- Lua 测试用 mock DB 或真 PG，不允许在 Lua 里直接拼 SQL string

## 备选方案 (Alternatives Considered)

- **ORM (sqlc / gorm / xo)**：
  - 否 — sqlc 生成的是 Go 代码，与 NCSoft 既有 SP 不兼容；gorm/xo 更不行
  - sqlc 调 SP 反而绕一层，没收益
- **Raw SQL + repository 模式**：
  - 否 — 业务规则散在 Go repository / Lua handler，违背"集中化业务规则"目标
  - 玩家 dup bug 的预防要在 repo 层重做，等于把 NCSoft 18 年的补丁扔了
- **自写 ORM + 编译期检查**：
  - 否 — 投资远大于收益；我们只有 1 人 + AI
- **MongoDB / Redis 主存**：
  - 否 — 物品 / 邮件 / 拍卖的事务原子性 NoSQL 做不到；关系型是硬约束
- **保留 SQL Server，不迁 PG**：
  - 否 — 国内 PG 部署 / 备份 / 容器化生态远好于 SQL Server；勒索事件后我们已铁律
    "PG only / 127.0.0.1 only"

## 引用 (References)

- `server/CLAUDE.md` — Key Constraint #1 "NEVER rewrite stored procedures"
- `server/doc/architecture.md` §5 状态持久化策略
- `server/doc/dev-guide.md` §0 Golden Rules / §2.3 Database Access Pattern
- NCSoft SP 源：`ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/`
- 移植脚手架：`server/sql/schema/`、`src/internal/database/migrations/`
- 测试基础设施：`src/internal/database/README.md`、`integration_test.go`
- 迁移工具：`server/doc/migration/`
- recent commits 说明 SP 移植节奏：`0ac9b4f` aion_AddItemUser、
  `da35a02` aion_GetAbyssPointUser、`cda6004` aion_GetCharIdByName、
  `5f37fb2` aion_GetBindPoint+SetBindPoint、`e4f6003` 角色生命周期 12 SP、
  `8257f48` instance/dungeon 20 SP
