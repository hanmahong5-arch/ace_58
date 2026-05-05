# 严格 Lint 基线说明 / AionCore Server golangci-lint

> **Round 13 B4 交付** | **Date**: 2026-05-05 | **Scope**: `ACE_5.8/server/`

## 1. 一句话 / TL;DR

`golangci-lint` 是 Go 生态事实标准 meta-linter (单进程并发跑 N 个 linter)。
本仓库**当前不强制** —— 走 **debt ratchet 模式**: 先把 config 落地 + 找 baseline, 由用户决定何时把 CI gate 收紧。
目的: 既不让"以为修干净了, 其实留了一堆错"的盲点继续生长, 也不让历史债把新 PR 一上来就卡红。

---

## 2. 安装 / Install

```bash
# 装最新版 (撰写本文档时为 v1.61+)
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# 验证
golangci-lint --version
which golangci-lint     # 应在 $(go env GOPATH)/bin
```

CI runner 上目前**未预装**, 由开发者本地按需运行。等 baseline 清零再考虑入 CI。

---

## 3. 启用的 linter / Enabled Linters

`.golangci.yml` 只开 6 个高信号 linter, 主动关掉了容易制造样式噪音的规则。

| Linter | 抓什么 bug | 为什么必要 |
|--------|-----------|----------|
| `errcheck` | 漏检查的 error 返回 | Lua VM/PG SP/NATS 调用必须每个 err 都看, 漏一个就是 silent corruption |
| `ineffassign` | 写了变量没用上 | 通常是 refactor 残留, 偶尔藏着真实 bug (变量被覆盖前没读) |
| `staticcheck` | SA* 全家桶 (含 nil 解引用、不可达代码、错误的 sync 用法) | 高信噪比的静态检查, Go 圈口碑顶级 |
| `govet` | `go vet` 全部规则 | CI 已跑 (`make lint`), 这里再显式声明保险 |
| `unused` | 跨包死代码 (函数/变量/字段) | 找出 round 之间留下的孤儿, 帮 surgical-changes 原则 |
| `gosimple` | 可简化的写法 | `if a == true` → `if a`, `for _ = range` → `for range`, 等等 |

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

> **TODO**: golangci-lint 在 Round 13 B4 落地时**未安装于本机** ($(go env GOPATH)/bin/golangci-lint 不存在)。
>
> 请开发者首次安装后运行 `make lint-strict` 自行获取实际 finding 数, 并把结果填入下表 + commit:

| 度量 | 值 | 备注 |
|------|----|----|
| golangci-lint 版本 | _待填_ | 用 `golangci-lint --version` |
| 总 finding 数 | _待填_ | `make lint-strict` 末尾汇总 |
| Top 1 linter | _待填_ | 哪个 linter 最噪 |
| Top 1 文件/包 | _待填_ | 哪个包债最多 |
| 跑分耗时 | _待填_ | `time make lint-strict` |
| 测试日期 | _待填_ | YYYY-MM-DD |

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
