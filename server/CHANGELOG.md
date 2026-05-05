# Changelog

All notable changes to AionCore 5.8 server are documented in this file.

The format is based on [Keep a Changelog 1.1](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 版本号 0.x.0 为开发预发布期暂用；首个对外 release 由用户决定切到 1.0.0 的时机。

---

## [Unreleased]

### Added
- 待用户标记下一次 release 的内容。

---

## [0.5.0] — 2026-05-05 — Engineering Hardening II

### Added
- CI 引入 PostgreSQL service container（`db-integration` job），SP 测试可在 GitHub Actions 跑通。
- `README.zh-CN.md` 重写为中文索引主入口；新增 `doc/architecture.md`、校准 `doc/lua-api.md`、
  `doc/opcodes.md`。
- `Dockerfile` + `docker-compose.dev.yml` 一键 bring-up 中间件（PG / Redis / NATS）。
- `.golangci.yml` 保守 6-linter 基线（debt ratchet 模式，参 `doc/lint.md`）。
- `Makefile` 新增 `lint-strict` / `lint-report` target。

_(commit a5309f1)_

---

## [0.4.0] — 2026-05-05 — Engineering Hardening I

### Added
- `.github/workflows/ci.yml` — `go vet` + `go test -race` + 覆盖率上报 + Lua 语法门。
- `internal/{crypto,luahost,database}/bench_test.go` — 关键路径微基准。
- `internal/telemetry/{prom,metrics,prom_test}.go` — Prometheus exporter。
- 新增文档：`doc/ci.md` / `doc/benchmarks.md` / `doc/observability.md` / `doc/coverage.md`。
- `Makefile` 新增 `lint` / `test` / `cover` / `bench` 与 CI 等价的本地 target。

_(commit f7f116a)_

---

## [0.3.0] — 2026-04-26 — Sprint -1：高熵 v0 + 嵌入式迁移

### Added
- Entropy v0 高熵机制：`forge_id` / `season_pool` / `manastone` / `random_attr` / `synergy`
  五个 Lua 全局命名空间。
- 启动时自动跑 goose migration，93 个 SP 进库。
- SP integration test rounds 6 / 7 / 8（共 337 个测试通过）。

_(commit 0fe0989)_

---

## [0.2.0] — 2026-04-24 — Phase S-19：副本 MVP

### Added
- Instance / Dungeon MVP — 状态机 + jobq expiry + daily reset。
- Haramel + Beshmundir 两张副本模板落地。
- 经 2 轮 plan-critic Gemini 红队评审打磨。

_(commit 5d23478，306 个测试通过)_

---

## [0.1.0] — 2026-04-13 ~ 04-14 — Phases S-0 ~ S-18

### Added
- Go 基础设施：进程脚手架、TOML 配置、结构化日志、pgx 连接池。
- ECS 框架 + gopher-lua VM 池 + bridge.go (Go→Lua API) + 沙盒。
- AION 协议栈：Blowfish-LE / RSA-1024 / XOR(seed=1234) 全量端到端验证。
- 5 进程拓扑：gateway / world / chat / logd / admin。
- 业务模块 Lua 脚本：战斗 / 技能 / 飞行 / 交易 / NPC AI / 任务 / 组队 / 军团 / PvP /
  装备 / 邮件 / 仓库 / 拍卖。
- LuaInvoker 桥 + jobq workers (asynq + Redis)。
- 角色生命周期 SP 链 12 个 + E2E 测试 + handler 修。

_(commits 08fda85 → e4f6003 → abaa3b1，274 个测试通过)_

---

## [0.0.1] — 2026-04-13 — 初始 scaffold

### Added
- 仓库初始化，目录骨架，CLAUDE.md 写定。
- 第一批 Phase S-0 ~ S-17 的 spike 代码。

_(commit 4a684ac)_

---

[Unreleased]: ./
[0.5.0]: ./
[0.4.0]: ./
[0.3.0]: ./
[0.2.0]: ./
[0.1.0]: ./
[0.0.1]: ./
