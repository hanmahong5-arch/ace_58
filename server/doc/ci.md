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

当前 `server/src/cmd/` 下有 8 个目录：

| cmd | 状态 | 入 CI |
|-----|------|------|
| `gateway` | 稳定（5 服务进程之一） | 是 |
| `world` | 稳定 | 是 |
| `chat` | 稳定（stub） | 是 |
| `logd` | 稳定（stub） | 是 |
| `admin` | 稳定（stub） | 是 |
| `tinyclient` | 稳定（端到端 smoke 工具） | 是 |
| **`spike`** | **WIP** — `int32` overflow in `encodeLootItemlist`，编译失败 | **否** |
| **`director`** | **WIP** — 另一 round 的 in-flight，行为未冻结 | **否** |

`./cmd/...` 通配会把 spike/director 拉进来一起红。CI 因此显式列出 6 个稳定 cmd 目标：

```bash
go build ./internal/... \
  ./cmd/gateway ./cmd/world ./cmd/chat ./cmd/logd ./cmd/admin ./cmd/tinyclient
```

**测试同理**：`go test ./internal/...` 只跑库代码测试，`./cmd` 下没有测试文件（cmd/* 是 main，靠 boot-test 在本地验证），所以 internal 范围已经覆盖全部 377 个 Go 测试。

WIP 的 spike/director 修好之后，把目录加回 `STABLE_CMDS` 即可恢复全量门。

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
