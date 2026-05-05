# 严格 Lint 基线说明 / AionCore Server golangci-lint

> **Round 13 B4 交付** | **Date**: 2026-05-05 | **Scope**: `ACE_5.8/server/`

## 1. 一句话 / TL;DR

`golangci-lint` 是 Go 生态事实标准 meta-linter (单进程并发跑 N 个 linter)。
本仓库**当前不强制** —— 走 **debt ratchet 模式**: 先把 config 落地 + 找 baseline, 由用户决定何时把 CI gate 收紧。
目的: 既不让"以为修干净了, 其实留了一堆错"的盲点继续生长, 也不让历史债把新 PR 一上来就卡红。

---

## 2. 安装 / Install

```bash
# 必须 v2 — v1 系列用 go1.23 编, 跑不动 go1.25 的项目 (报 "Go language version
# (go1.23) used to build golangci-lint is lower than the targeted Go version (1.25)")
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

# 验证 (撰写本节时跑出 v2.12.1, build go1.25.9)
golangci-lint --version
which golangci-lint     # 应在 $(go env GOPATH)/bin
```

CI runner 上目前**未预装**, 由开发者本地按需运行。等 baseline 清零再考虑入 CI。

**v1 → v2 schema 注意**: `.golangci.yml` 必须含 `version: "2"`; `linters.disable-all` → `linters.default: none`; `gosimple` 已并入 `staticcheck` (S* 系列由 staticcheck 接管); `issues.exclude-rules` → `linters.exclusions.rules`。本仓库的 `.golangci.yml` 已迁完, 用 `golangci-lint migrate` 一键转的。

---

## 3. 启用的 linter / Enabled Linters

`.golangci.yml` 只开 5 个高信号 linter (v2 把 gosimple 合并进 staticcheck, 信号不丢), 主动关掉了容易制造样式噪音的规则。

| Linter | 抓什么 bug | 为什么必要 |
|--------|-----------|----------|
| `errcheck` | 漏检查的 error 返回 | Lua VM/PG SP/NATS 调用必须每个 err 都看, 漏一个就是 silent corruption |
| `ineffassign` | 写了变量没用上 | 通常是 refactor 残留, 偶尔藏着真实 bug (变量被覆盖前没读) |
| `staticcheck` | SA* + S* + ST* + QF* 全家桶 (v2 合并 gosimple, 含 nil 解引用、不可达代码、可简化写法) | 高信噪比的静态检查, Go 圈口碑顶级 |
| `govet` | `go vet` 全部规则 | CI 已跑 (`make lint`), 这里再显式声明保险 |
| `unused` | 跨包死代码 (函数/变量/字段) | 找出 round 之间留下的孤儿, 帮 surgical-changes 原则 |

**没开**:
- `gocyclo` / `funlen` / `lll`: 风格类, 容易和现有代码风格干架
- `gocritic` / `revive`: 规则太多, 误报概率高, 后续 round 再选择性开
- `gosec`: 安全扫描需要单独 round 评估 (crypto 包会触发大量自定义 BF/RSA 实现的"假阳性")

---

## 4. 排除规则 / Exclusions

| 排除项 | 原因 |
|--------|------|
| `_test\.go` 的 `errcheck` | 测试代码允许 `db.Exec(...)` 不接 err, 写法太啰嗦反而劣化测试可读性 |
| `src/cmd/spike/` 全 linter | WIP — 有 `int32` overflow 已知问题, 与 ci.yml 范围对齐 (见 doc/ci.md §2) |
| `src/cmd/director/` 主要 linter | WIP — 另一 round 的 in-flight, 行为未冻结 |
| `vendor/` 目录 | 第三方代码, 不归我们管 |
| `staticcheck SA1019` (deprecation) | pgx/v5 等依赖升级会带来一波过时 API 噪音, 留作集中治理 |

---

## 5. 工作流 / Workflow

### 5.1 写新代码时

```bash
cd D:/拾光ai/ACE_5.8/server
make lint-strict
```

观察输出。**关注**: 自己这次改动有没有引入**新** finding。
如果 finding 完全在你改过的文件之外, 那是历史债, 暂时不修不丢人。

### 5.2 修 bug 时

```bash
make lint-report      # 写到 doc/lint-baseline.txt
git diff doc/lint-baseline.txt
```

把 baseline 文件 diff 一下, 看有没有"修着修着 finding 数变多"。变多就回滚思考。

### 5.3 不强制 / Not Gated

- CI **不**跑 `make lint-strict` (见 `.github/workflows/ci.yml` 当前只有 `go vet`)
- PR 不会因 lint finding 红
- 这是有意的: 让历史债不阻塞新功能, 但也不让它继续涨

### 5.4 未来 / Roadmap

收紧 CI gate 的触发条件 (任一即可):

1. **baseline finding 数降到 0** → 加 `make lint-strict` 到 `go-ci` job, 任何新 finding 直接 PR red
2. **某次大重构清理了大半 finding** → 把当前数定为 ceiling, 后续不允许超过
3. **某条 linter 单独清完** → 单独那条 linter 入 CI, 其他保持非强制

参考 `doc/ci.md` 的 ratchet 风格设计。

---

## 6. 当前 Baseline / Current Findings

**首次落地: 2026-05-05** — golangci-lint 装好之后跑出的真实数字 (用 `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` 装的 v2.12.1)。**Ratchet 第一次往下: 59 → 51** (清掉 §6.3 里 8 处真实债)。

| 度量 | 值 | 备注 |
|------|----|----|
| golangci-lint 版本 | v2.12.1 (build go1.25.9) | v1 系列已死, 必须 v2 (用 go1.25 编, 与项目 go 版本对齐) |
| 总 finding 数 (初始) | 59 | 8 处真实债清理前 |
| 总 finding 数 (当前) | **51** | 见 `doc/lint-baseline.txt` 全文 |
| Top 1 linter | **staticcheck (51)** | 占 100% — 全是 ST1003 + 1 QF1012 |
| Top 1 文件/包 | **`src/internal/aionproto/opcodes.go` (50)** | 占 98.0% — 全部是 CM_/SM_ 协议常量被判为 ALL_CAPS |
| Top 1 finding code | **ST1003 (50)** | "should not use ALL_CAPS in Go names" |
| 跑分耗时 | **2.4s** | `time make lint-strict` (Windows 本机, 8 core, debt 清理后跑得更快) |
| 测试日期 | 2026-05-05 | Round 13 收尾 + ratchet down |

### 6.1 Findings 分布 / Distribution (当前 51)

```
staticcheck  : 51
  ├── ST1003 : 50  ← 全部 opcodes.go: CM_*/SM_* 协议常量 (领域约定)
  └── QF1012 : 1   (spsynth/prompt.go: 另一会话 untracked, 暂不动)
```

### 6.1.1 已清真实债 (commit 37756e4 之后, ratchet 第一次往下)

| # | 文件:行 | code | 修法 |
|---|--------|------|----|
| 1 | `luahost/s19_test.go:825` | ineffassign | 删 dev 注释残留, 直接用正确的 LE 字节 |
| 2 | `luahost/s19_test.go:276` | SA9003 | 空分支改 `_ = L.DoString(...)` 显式忽略 setup err |
| 3 | `crypto/rsa.go:93` | QF1008 | `k.priv.PublicKey.N` → `k.priv.N` (embedded field) |
| 4 | `crypto/rsa.go:102` | QF1008 | `k.priv.PublicKey.E` → `k.priv.E` |
| 5 | `database/sp_pve_round7_test.go:381` | QF1001 | `if !(a && b && c)` → `if !a \|\| !b \|\| !c` (De Morgan) |
| 6 | `database/sp_pve_round9_test.go:244` | QF1003 | `if/else if iid==X` → `switch iid { case X }` |
| 7 | `ecs/world_buff_test.go:56` | SA4006 | 删冗余 `snapshot = snapshot[:0]` (slice 头是局部变量, 不可能影响 store) |
| 8 | `database/sp_get_char_id_by_name_test.go:23` | ST1003 | `charIdByNameCleanup` → `charIDByNameCleanup` (Go 命名 ID 大写) |

### 6.2 ST1003 决策建议 / Decision Note

51/59 finding 集中在 `aionproto/opcodes.go` 的 `CM_*` / `SM_*` 协议常量上, 是 staticcheck 报"should not use ALL_CAPS in Go names" (ST1003)。

**决策建议: 应豁免 ST1003 在 `aionproto` 包内的检查**, 因为:
- AION 5.8 协议规范本身就用 `CM_AUTH_LOGIN` / `SM_LOGIN_OK` 这种命名, 跨语言 (C++/Rust/Java/Go) 都遵守
- NCSoft 文档 / 反编译资料 / 1314 SP 全部用此命名风格
- 改成 CamelCase (`CmAuthLogin`) 反而劣化"我在看协议代码"的领域识别
- 这是典型的"通用 lint 规则与领域约定冲突"

要落地豁免, 在 `.golangci.yml` `exclusions.rules` 加一条:

```yaml
- linters:
    - staticcheck
  text: "ST1003"
  path: src/internal/aionproto/
```

**当前不动** — 留给下个 round 评审决策, 这一节先把 baseline 锁成 ratchet 起点。

### 6.3 真实债 / True Debt — 已清 8/9 ✅

8 处真实债已在 ratchet 第一次往下时清完 (见 §6.1.1)。当前剩 1 处:

| 文件 | 行 | code | 描述 | 状态 |
|------|----|------|------|----|
| `spsynth/prompt.go` | 46 | QF1012 | `WriteString(fmt.Sprintf(...))` → `fmt.Fprintf` | **暂不动** — 另一会话 untracked, 等合流再清 |

清完后 baseline = **51** (含 50 ST1003 领域噪音), 排除 ST1003 后 = **1**。

填完之后这一节就是 ratchet 的起点 — 后续 round 拿这个数对比"今天比上次多还是少"。

---

## 7. 与 `make lint` 的关系 / Relation to `make lint`

| 命令 | 跑什么 | 作用域 | 强制 |
|------|--------|--------|------|
| `make lint` | `go vet ./internal/...` | CI 跑, PR red | 是 |
| `make lint-strict` | `golangci-lint run` (6 linter) | 仅本地 | 否 |
| `make lint-report` | 同上, 输出到文件 | 仅本地 | 否 |

`go vet` 是 ground truth — 强制门。`golangci-lint` 是**叠加在 vet 之上的可选层**, 提供更广覆盖但允许债务存在。

不要把 `lint-strict` 和 `lint` 混淆: `lint` 失败必须修, `lint-strict` 失败先看是不是历史债。

---

## 8. 常见问题 / FAQ

**Q: 为什么不直接开全 linter?**
A: golangci-lint 默认只开 6 个 (errcheck/gosimple/govet/ineffassign/staticcheck/unused), 我们这份配置就是这个集合 + 显式声明。开全集 (40+ linter) 在干净仓库上能跑出几千条 finding, 一个 round 修不完, 反而劣化信号。

**Q: 在 cmd/gateway 等稳定 cmd 上为什么不跑 lint?**
A: 当前 `make lint-strict` 只看 `./internal/...` 与 `make lint` 对齐。等内部干净了再扩到 6 个稳定 cmd 目录 (gateway/world/chat/logd/admin/tinyclient)。

**Q: lint findings 能不能 auto-fix?**
A: golangci-lint 部分 linter 支持 `--fix`, 但本 round 是 baseline-only, 不在范围内。要 auto-fix 单独开 round, 评审过 diff 再合。

**Q: VS Code 集成?**
A: `Go: Lint Tool` 设为 `golangci-lint`, `Go: Lint Flags` 设为 `["--config=${workspaceFolder}/ACE_5.8/server/.golangci.yml"]`, 保存即跑。

---

## 9. 相关文档 / References

- `doc/ci.md` — CI 基线 (`go vet` 强制门所在)
- `doc/dev-guide.md` — 三层架构 / 编码圣墙
- `.golangci.yml` — 配置文件本体 (本文档讲的 why, 那里讲 what)
- 上游: https://golangci-lint.run/
