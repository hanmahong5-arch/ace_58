# 测试覆盖率基线（2026-05-05）

本文档为 AionCore 5.8 Go 运行时（`server/src/internal/...`）的测试覆盖率基线快照，作为 A4 任务（4-agent swarm 加固）的产出。

## 概要

| 指标 | 值 |
|---|---|
| **总语句覆盖率** | **69.5%** |
| 已测试包数 | 10 |
| 无测试文件包数 | 3（`config` / `ipc` / `session`） |
| 子测试 PASS 总数 | 377 |
| 子测试 SKIP 数 | 19（全部在 `internal/database`，需 `AION_TEST_PG_HOST` 真库） |
| FAIL 数 | 0 |
| 复跑命令 | `make cover`（A1 agent 提供） |

> 数据来源：`go test ./internal/... -count=1 -coverprofile=/tmp/cov.out -covermode=atomic` + `go tool cover -func=/tmp/cov.out`，2026-05-05 快照。
> `cmd/spike` 当前损坏，本基线刻意限定 `./internal/...`。

## 各包覆盖率（从高到低）

| 包名 | 覆盖率 | 测试数（PASS 子测试） | 备注 |
|---|---:|---:|---|
| `internal/ecs` | **99.3%** | 21 | ECS 核心，覆盖率近满分，黄金参考 |
| `internal/aionproto` | **98.8%** | 9 | 协议层 opcode/codec，对照 NCSoft 反编译，几乎全覆盖 |
| `internal/crypto` | **85.1%** | 17 | BF-LE / RSA-NoPad / XOR 全栈测试，唯一缺口在 `blowfish_le.go:42` 一处错误分支 |
| `internal/persona` | **76.9%** | 5 | LLM 人格层，registry 一函数 0% |
| `internal/memory` | **75.5%** | 5 | 内存事件存储，`fake_store.go` 两函数 0% |
| `internal/luahost` | **69.9%** | 287 | Lua VM host，含 14 个 round-trip + handler/event/skill 集成；测试数最多 |
| `internal/spsynth` | **61.7%** | 11 | SP 合成器，`schema.go:45` / `validator.go:44` 两函数 0% |
| `internal/jobq` | **55.3%** | 17 | jobq worker，`bundle.go` 三函数 + `workers.go:159` 共 4 处 0% |
| `internal/director` | **55.0%** | 5 | director actions 半数函数未覆盖（见薄弱节） |
| `internal/database` | **0.0%** | 0（19 SKIP） | 集成测试，需真 PG；非缺失，是隔离 |
| `internal/config` | — | — | 无测试文件 |
| `internal/ipc` | — | — | 无测试文件 |
| `internal/session` | — | — | 无测试文件 |

## 薄弱包（<60%）— 补测建议

下列包覆盖率低于 60%，对生产可靠性形成潜在风险。**仅给出建议，本任务不实施补测**。

### 1. `internal/database` — 0.0%（19/19 SKIP）

**根因**：所有测试均要求 `AION_TEST_PG_HOST` 环境变量，未设置则 SKIP。CI 中无真 PG，覆盖率为 0 是预期表现，但留下盲区。

**建议**：
- CI 引入 PostgreSQL service container（GitHub Actions 已支持），把 `AION_TEST_PG_HOST=localhost` 注入，让 19 个 SP round-trip 测试真跑。
- 对纯 Go 函数（`pool.go` 12 个零覆盖、`migrate.go:43`）拆出 unit-level 测试，无需 PG（mock `*sql.DB`）即可跑通。
- 优先保护：`pool.go` 的 connection lifecycle（30/58/63/68/76/91/105/112/124/145/165 行的 11 个零覆盖函数）— 是热路径，连接泄漏会立刻打爆生产。

### 2. `internal/director` — 55.0%

**根因**：`actions.go` 32/56/80/103/113/114/115/117 行 8 个函数完全 0%。这些是 director 的核心动作分发器。

**建议**：
- 写 director 状态机的 happy-path 集成测试（`Trigger → Action → Effect`），一次性覆盖所有 action handler。
- 不必追每个 action 的边缘错误，但**至少每个 action 跑过一次**（防止「写了不调用」的死代码）。

### 3. `internal/jobq` — 55.3%

**根因**：`bundle.go:154/192/221` 三个 bundle lifecycle 函数 + `workers.go:159` 一个 worker 路径未覆盖。jobq 是 NATS JetStream 桥接核心，hot path 必须保证。

**建议**：
- 补 bundle ack/redeliver/dead-letter 三条路径（对应 154/192/221）的集成测试，用 in-memory NATS server。
- `workers.go:159` 单测覆盖即可。

## 强壮包（>80%）— 正面参考

下列包是高覆盖率的工程典范，新增模块应参照其测试组织：

### 1. `internal/ecs` — 99.3%

22 个文件、21 PASS。ECS 核心数据结构与系统循环；测试与实现一对一，table-driven，无 mock。**新写 Go 服务模块的标杆**。

### 2. `internal/aionproto` — 98.8%

20 个文件、9 PASS（每个 PASS 含大量 sub-test）。对照 `ai/wiki/raw/47104-sp-dump/` 与 NCSoft 反编译做的 round-trip + golden file。**协议层就该这样测**。

### 3. `internal/crypto` — 85.1%

20 个文件、17 PASS。BF-LE / RSA-NoPad / XOR 三件套，KAT（Known-Answer-Test）+ fuzz。唯一未覆盖是 `blowfish_le.go:42` 的越界保护分支，可不强求。

## 如何降低 cardinality 但提高 confidence

不要为追 100% 而追。本基线的指导原则：

1. **Hot path 必须 ≥80%**：crypto / aionproto / luahost / ecs / jobq / database 的核心 API（连接、解码、handler 分发、worker loop）。
   - 当前 5/6 达标；`jobq` 需补 bundle 三路径，`database` 需 CI 加 PG。
2. **冷路径只要不 0%**：错误处理、CLI flag 解析、debug helper 等。0% 表示「写了从未调用」，是死代码信号；写一个最简单的测试能跑通即可。
3. **集成测试胜过 unit 数量**：`luahost` 287 PASS 大部分是 round-trip 集成（脚本 → handler → DB SP），1 个集成测试胜过 10 个 mock 单测。
4. **SKIP 不算失败但要可见**：`database` 19 SKIP 在本地正确，但 CI 必须把它们激活，否则 SP 移植回归无法被自动捕捉。
5. **`config`/`ipc`/`session` 无测试是债**：三个包共计若干文件无 `_test.go`。短期可接受（被上层间接调用），但应列入「下一波加固清单」。

## 复跑

```bash
# 一次性
cd D:/拾光ai/ACE_5.8/server/src
go test ./internal/... -count=1 -coverprofile=/tmp/cov.out -covermode=atomic
go tool cover -func=/tmp/cov.out | tail -1     # 总覆盖率
go tool cover -html=/tmp/cov.out               # 浏览器看热图

# 通过 Makefile（A1 agent 已添加）
make cover
```

## 历史

| 日期 | 总覆盖率 | 测试数 | 备注 |
|---|---:|---:|---|
| 2026-05-05 | 69.5% | 377 PASS / 19 SKIP | A4 任务建立基线 |
