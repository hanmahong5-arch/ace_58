# 参与贡献 — AionCore 5.8

欢迎。本项目是"拾光AI = 光辉永恒"高熵 AION 5.8 私服的核心服务端，作者人少、口味挑、欢迎一切让代码更
诚实的修改。本文是给第一次提交 PR 的 contributor 的入门读物。

---

## 5 分钟读懂这个仓库

按这个顺序看，不要跳：

1. [`README.zh-CN.md`](./README.zh-CN.md) — 项目定位 / 启动命令 / 当前状态。
2. [`doc/architecture.md`](./doc/architecture.md) — 三层架构（Go runtime / Lua scripts / PG SP）+ 数据流。
3. [`doc/dev-guide.md`](./doc/dev-guide.md) — **Source of Truth**：硬约束清单。
4. [`doc/adr/README.md`](./doc/adr/README.md) — Architecture Decision Records 索引（如已建立）。
5. [`CHANGELOG.md`](./CHANGELOG.md) — 历史变更，给上下文用。

如果上述任何一处与实际代码不符，提一个 issue 标 `docs` — 文档跟代码同等重要。

---

## 开发环境 setup

### 必备依赖

- **Go** 1.25+（看 `go.mod` 的 `go` 指令）
- **PostgreSQL** 16+（仅 `127.0.0.1`，**不要绑公网**，红线之一）
- **Redis** 7+（dev 可用 `tools/devredis/devredis.exe` 单二进制 miniredis 替代）
- **NATS** 2.10+（`go install github.com/nats-io/nats-server/v2@latest`）
- **Make**（GNU Make 4.x；Windows 可用 git-bash 自带或 MSYS2）

### 一键拉中间件（推荐）

```bash
# 在仓库根目录的 server/
docker compose -f docker-compose.dev.yml up -d
# 详见 doc/docker.md
```

### 拉源码 + 装依赖

```bash
git clone <repo-url>
cd <repo>/server
go -C src mod download
```

### 跑首次测试

```bash
make test          # ./internal/... 全量 + -race（约 30 秒）
make help          # 列出所有可用 target
```

如果 `make test` 第一次就红：先看 [`doc/dev-boot-checklist.md`](./doc/dev-boot-checklist.md)。

---

## 改动清单 / 提交规范

### 单 PR 单关注点

不要把"修一个 bug + 顺手 refactor + 调一个无关 typo"塞同一个 PR。Reviewer 会要求拆分。

### Commit message 风格

参考 `git log --oneline -20` 已有风格。基本形如：

```
<scope>: <imperative summary>

<可选 body：动机 / 怎么做 / 为什么这样做>
```

例：

- `SP: aion_GetCharIdByName (mail recipient resolution)`
- `Round-10 F4: 5 进程拓扑端到端 boot-test 落地`
- `engineering hardening II: PG container CI + docs hierarchy + Docker + lint`

### 测试要求

- 新功能：**目标覆盖率 ≥ 80%**（用 `make cover` 看本地数字）。
- Bug 修复：**至少 1 个复现测试**（先红 → 再绿，TDD 流程）。
- 不要为了凑覆盖率写假测试 — reviewer 一眼能看出来。
- Lua 业务脚本：用 `internal/luahost/*_test.go` 的方式起 VM 跑断言。

### Lint

```bash
make lint           # 必过 — go vet ./internal/...
make lint-strict    # 可选信号 — golangci-lint 全 linter（debt ratchet 模式，详见 doc/lint.md）
```

---

## PR 流程

1. **建分支**：`git checkout -b <type>/<short-slug>`，`<type>` ∈ `{feat, fix, docs, chore, refactor, test}`。
2. **改代码 + 写测试**（TDD 优先）。
3. **本地三连**：`make lint && make test && make cover`，cover 不能比 main 低。
4. **看 `make help`**：确认没漏掉与你改动相关的本地 gate。
5. **提 PR**，描述必含三段：
   - **动机** — 解决什么问题 / 实现什么需求？link issue 编号。
   - **验证** — 怎么证明它工作？哪些测试 / 哪些手动场景？
   - **风险** — 改动可能在哪些边界 case 失效？怎么 rollback？
6. **架构/协议改动** — 提 PR 前先开 issue 讨论，或先写 ADR（`doc/adr/NNNN-*.md`）。

---

## 红线（违反直接打回）

1. **不要直接 push `main`** — 全部走 PR + review。
2. **不要把 PostgreSQL 绑公网** — 仅 `127.0.0.1`（2026-04-11 勒索事件教训）。
3. **不要在 Go / Lua 写 inline SQL** — 业务逻辑只能调 PG 存储过程（见 `doc/adr/0003-*.md` 如已建立）。
4. **不要硬编码** — 端口 / rate / 副本参数全部走 TOML 或 PG。
5. **不要删 ADR** — 历史决策只能 `Status: Superseded by ADR-XXXX`，不能消失。
6. **不要编辑别人未提交的工作树文件** — 多 AI 会话并发协议见 `../CLAUDE.md` 的 "并发会话协议"。
7. **不要 `git commit --no-verify`** — 跳过 hook 是说"我知道这次会破坏 main"；99% 时候不该用。

---

## 沟通

- **Bug / 改进想法**：开 GitHub issue，标对应 label。
- **架构讨论 / 大改提议**：先开 `proposal:` issue，再决定要不要写 ADR / PRD。
- **紧急生产问题**：见 `doc/runbook.md` 的 oncall 流程（如已建立）。

---

## 行为准则

简短版：

- **尊重彼此**：批评代码不批评人。
- **技术诚实**：不知道就说不知道；不要假装跑过没跑过的测试。
- **及时止损**：方向错了立刻说，越早越好；沉没成本不是理由。

---

*本文档跟代码同步演进。如果你照做发现哪一步过时了，请提 PR 修文档 — 这本身就是有效贡献。*
