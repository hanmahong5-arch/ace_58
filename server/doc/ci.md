# CI 基线说明 / AionCore Server CI

> **Round 13 A1 交付** | **Date**: 2026-05-05 | **Scope**: `ACE_5.8/server/`

## 1. 为什么有 CI / Why

CI 是 **回归门** + **绿色信号源**：

- **回归门**: PR 合入 main 前必须 vet/build/test 三关全绿，避免 main 被某个 round 的 WIP 带红。
- **信号源**: 多 agent 并发改动时，CI 红/绿是唯一可信的"当前 main 是否能跑"指标 — 不依赖任何人本地环境。
- **保护资产**: 274 + 87 Lua 测试是 S-0 ~ Sprint -1 累积的回归网，必须每次提交跑一遍 `-race`。

不做的：
- 不发 release 工件（debug-only 路线，与全局 CLAUDE.md 对齐）。
- 不跑 `golangci-lint` 全家桶（基线先要"明显错误"门，后续 round 再加严）。
- 不在 CI 起 PostgreSQL（仓库根 `.github/workflows/ci.yml` 有独立的 integration job 处理）。

---

## 2. 为什么作用域是 `./internal/...` / Scope Rationale

当前 `server/src/cmd/` 下有 9 个目录：

| cmd | 状态 | build | test |
|-----|------|-------|------|
| `gateway` | 稳定（5 服务进程之一） | 是 | 无测试文件 |
| `world` | 稳定 | 是 | 无测试文件 |
| `chat` | 稳定（stub） | 是 | 无测试文件 |
| `logd` | 稳定（R5 实装：NATS→ClickHouse pipeline） | 是 | **是 (7)** |
| `admin` | 稳定（R5 实装：chi REST + JWT + rate limit） | 是 | **是 (25)** |
| `tinyclient` | 稳定（端到端 smoke 工具） | 是 | 是 (1+) |
| `loadgen` | 稳定（R5 新增：协议级压测，与 tinyclient 互补） | 是 | **是 (12)** |
| **`spike`** | **WIP** — `int32` overflow in `encodeLootItemlist`，编译失败 | **否** | — |
| **`director`** | **WIP** — 另一 round 的 in-flight，行为未冻结 | **否** | — |

`./cmd/...` 通配会把 spike/director 拉进来一起红。CI 因此显式列出 7 个稳定 cmd 目标：

```bash
go build ./internal/... \
  ./cmd/gateway ./cmd/world ./cmd/chat ./cmd/logd ./cmd/admin ./cmd/tinyclient ./cmd/loadgen
```

**测试**（**2026-05-06 修订**）：
原断言"./cmd 下没有测试文件"在 R5 swarm 后已**不再成立**。当前 cmd 测试分布:

```bash
go test ./internal/... \
  ./cmd/admin ./cmd/logd ./cmd/loadgen ./cmd/tinyclient \
  -race -count=1 -timeout=5m -coverprofile=coverage.out
```

gateway/world/chat 是 main 无测试，CI 不显式纳入 test step（跑了也是 `[no test files]`，
浪费 race 编译时间）。覆盖率以 `internal/...` 为主，cmd 子集是回归保护层。

WIP 的 spike/director 修好之后，把目录加回 `STABLE_CMDS`/`TESTABLE_CMDS` 即可恢复全量门。

---

## 3. 本地等价命令 / Local Equivalents

CI 的每一步都能在本地 Makefile 复现：

```bash
cd D:/拾光ai/ACE_5.8/server

make lint     # = go vet ./internal/...
make test     # = go test ./internal/... -count=1 -race -timeout=5m
make cover    # = go test ... -coverprofile=coverage.out -covermode=atomic
              #   + go tool cover -func 末行
make bench    # = micro-bench crypto / luahost / database
```

提交前推荐顺序：`make lint && make test && make cover`。三者全绿，CI 必绿。

---

## 4. 覆盖率工件解读 / Coverage Artifact

CI job `go-ci` 上传 `coverage-internal.zip`（`server/src/coverage.out`，保留 14 天）。

下载后查看：

```bash
# 末行总覆盖率
go tool cover -func=coverage.out | tail -1

# 按文件展开
go tool cover -func=coverage.out

# 浏览器打开 HTML 热点图
go tool cover -html=coverage.out -o cover.html
start cover.html   # Windows
```

**当前基线（2026-05-05 Round 13 A1）**: 仅作信号，不设硬阈值。
后续 round 引入阈值门时，建议从"任一包不得低于上次值 - 5pp"起步，避免一刀切误伤新文件。

---

## 5. Lua 语法门 / Lua Syntax Gate

`lua-syntax` job 是 best-effort：

- 仅在 runner 提供 `luac` 时跑（`command -v luac` 探测）。
- 缺则 echo "skipping" 跳过，不阻塞 PR。
- 跑则 `luac -p` 批量校验 `scripts/**/*.lua`，单文件失败用 `::error file=` 标 PR。
- 整 job 标 `continue-on-error: true`，即便误报也不阻断 go-ci。

理由：Lua 语法错误在运行时（hot-reload）才暴露太晚；但 CI runner Lua 工具链不是 first-class，做硬门会引入 flaky。当前定位：**早期信号，后续如果稳定，再切硬门**。

---

## 6. 触发与并发 / Triggers & Concurrency

```yaml
on:
  push:    branches: [main],   paths: ['ACE_5.8/server/**', '.github/workflows/ci.yml']
  pull_request: branches: [main], paths: ['ACE_5.8/server/**']

concurrency:
  group: aioncore-server-${{ github.ref }}
  cancel-in-progress: true
```

- **paths 过滤**: 只在 server 树或本工作流自身变更时触发，避免 `BEY_4.8/` `platform/` 改动浪费 minutes。
- **同分支并发取消**: PR 连续 push 时，旧 run 自动停掉只跑最新。

---

## 7. 与仓库根 CI 的关系 / Relation to Root CI

仓库根 `.github/workflows/ci.yml`（Round 12 A3 留下）跑 `go ./...` 全量编译 + PG canary。
当前因 cmd/spike WIP **已知会红**，这是另一 round 的范围。

本工作流（`server/.github/workflows/ci.yml`）是 **server 子仓的绿色基线**，给 R13 后续 round 提供稳定信号。
两者并存，互不干扰：

- 根 CI 失败 → 关注 spike/director WIP 是否修完
- 本 CI 失败 → 关注 internal/ 或 6 个稳定 cmd 是否被引入了回归

WIP 全部修完之后，建议合并两个工作流为一个，避免双跑。

---

## 8. 故障排查速查 / Troubleshooting

| 现象 | 可能原因 | 处置 |
|------|---------|------|
| `go vet` 红 | 新代码触发 vet 规则（`shadow` / `printf` 等） | 本地 `make lint` 复现，按 vet 提示修 |
| `go build` 红，提示 cmd/spike 或 cmd/director | 误用了 `./cmd/...` 通配 | 检查 ci.yml `STABLE_CMDS` 是否被改坏 |
| `go test -race` 红，本地 `go test` 绿 | 并发数据竞争 | 复现：`go test -race -run TestXxx ./internal/yyy`；多半是 map/slice 非锁共享 |
| `coverage-internal` 工件缺失 | go test 在产 coverage.out 之前就红了 | 看 test 步骤日志；先修 test |
| lua-syntax skip | runner 没装 luac | 正常行为，不阻塞 |

如需手动重跑：GitHub Actions UI → Re-run failed jobs（不会重跑成功的）。

---

## 9. PG 集成测试 / `db-integration` job

### 9.1 为什么需要 / Why

`internal/database/` 下有 19 个 SP 集成测试（`sp_*_test.go`、`migrate_test.go`、`bench_test.go`），全部通过 `testDSN()` 走 **`AION_TEST_PG_HOST/PORT/DB/USER/PASS` 五元组 env-gate**：

- 任何环境变量缺失 → `t.Skipf("integration skipped: ...")` 干净跳过
- 默认 `go test ./...` 在没本地 PG 的贡献者机器上不会红，也不会跑

后果：`go-ci` 把这些测试 `SKIP` 掉，`internal/database` 包的 coverage 报告显示 **0%**。19 个测试全是真打 PG、真跑 135 个嵌入 migration、真过 SP 签名 — 不跑就是 0% 信号。

`db-integration` job 在 CI 里把这层 env-gate 注入进去，把 `internal/database` 覆盖率从 0% 拉到 ~80%+，是单包 ROI 最高的一档。

### 9.2 为什么用 service container（vs self-hosted PG）/ Why Service Container

| 选项 | CI 隔离 | fresh DB | 配置漂移 | 暴露面 | 与 ransomware 教训冲突 |
|------|---------|----------|----------|--------|----------------------|
| **GitHub Actions service container** | ✅ 每 run 独立 | ✅ 每次 fresh | ✅ 无 | runner localhost 5432 | ❌ 不沾边 |
| self-hosted PG (本机 / 远端) | ❌ 跨 run 污染 | ❌ 需手 reset | ❌ 易漂 | 可能公网 | ⚠️ 与 2026-04-11 教训冲突 |

仓库铁律 "PG 仅 127.0.0.1" 是针对**生产数据**的；service container 启在 GitHub runner 本机上，外部完全不可达，符合精神。

### 9.3 配置注入 / Env Vars Injected

`.github/workflows/ci.yml` 的 `db-integration.steps[*].env` 段：

```yaml
AION_TEST_PG_HOST: localhost
AION_TEST_PG_PORT: '5432'
AION_TEST_PG_USER: aion_test
AION_TEST_PG_PASS: aion_test
AION_TEST_PG_DB:   aion_test
```

对应 service container 的 `POSTGRES_USER/PASSWORD/DB` 全部 `aion_test`（CI 用临时账号，不与生产任何凭据复用）。

### 9.4 Migration 自动跑 / Migrations Are Auto-Applied

不在 CI 里独立加一步 `go run ./cmd/migrate`，原因：

1. `Migrate()` 是包内函数，没有独立 cmd 入口（embed.FS 已经把 135 个 `*.sql` 编进去）
2. 所有依赖 schema 的 Test 都按既定 pattern 自己调 `Migrate(ctx, dsn)`（见 `migrate_test.go`、`sp_bind_point_test.go` 第 41 行）
3. `goose` 的版本表 `goose_db_version` 让重复 `Migrate` 是 **no-op**（详见 `TestMigrateIdempotent`）
4. 保持与本地 `go test` 行为一致 — 最小化"CI 绿本地红"或反过来的风险

第一个 Test 调 `Migrate()` 会把 135 个 `*.sql` 全跑一遍（约几秒），之后所有 Test 共享 schema。

### 9.5 工件 / Artifacts

`db-integration` 单独上传 `db-coverage.out`，与 `go-ci` 的 `coverage-internal.zip` **不冲突**：

- 工件名 `db-coverage`（vs `coverage-internal`）
- 内容只覆盖 `./internal/database/...`
- 想合并两个报表：本地下载两个 `.out`，`go tool cover -func` 分别看，或拼成一个

### 9.6 故障排查 / Troubleshooting

| 现象 | 可能原因 | 处置 |
|------|---------|------|
| step "Initialize containers" 红 | service container `pg_isready` 探测 10 次 (50s) 仍失败 | 看 GitHub Actions UI 的 service container 日志；多半是 `postgres:17-alpine` 镜像 pull 失败或 GitHub 临时故障，re-run 即可 |
| `go test` 直接 ECONNREFUSED 5432 | env vars 没注进 step（YAML 缩进错） | 检查 `db-integration.steps[*].env` 段；`localhost:5432` 必达 |
| `goose: failed to apply migration` | embed 的某 `*.sql` 在 PG17 上行为变化 | 本地 `make test` 复现：`AION_TEST_PG_*` 指 PG17 容器；多半是某 SP DDL 写法在新版本 PG 严格化了 |
| Test 红 "function aion_xxx does not exist" | migration 没跑成功，但前面没在 step 里报错 | 调 `go test -v` 看第一个 Test 的 `Migrate` log；afterVer 应该是 135（当前 migration 数）|
| 端口冲突 5432 | runner 本身极少占用，但若发生 | 改 `ports: 15432:5432` + `AION_TEST_PG_PORT: '15432'` |
| 跑得太慢（>10m timeout） | 19 个 Test 平均应 ~1-2min；明显超过说明 SP 死锁或 PG 资源不足 | 查最后一个开始的 Test，多半是 `sp_pve_round*` 的 cleanup 没收尾 |

### 9.7 与本地 `make test` 的关系

本地有 PG 时（`AION_TEST_PG_*` 已 export），`make test` 同样会跑全 19 个 SP 集成测试。
CI 的 `db-integration` job 是 **本地行为在 runner 上的复刻**，不引入额外 magic。

如果本地绿、CI 红：
- 99% 是 PG 版本不一致 — 本地可能是 PG14/15，CI 是 PG17
- 1% 是 timezone / locale — service container 默认 UTC，本地可能是 Asia/Shanghai
