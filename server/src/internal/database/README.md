# `internal/database` — PostgreSQL 接入层

包责任：连接池 + 迁移执行 + 存储过程薄封装。**不写业务 SQL**——所有
INSERT/UPDATE/DELETE 走 `aion_*` 已迁移存储过程（参见 `sql/schema/`）。

## 文件清单

| 文件 | 作用 |
|------|------|
| `pool.go` | `pgxpool.Pool` 包装 + `CallSP` / `CallSPRow` / `CallSPExec` / `InTx` |
| `migrate.go` | goose v3 + embed.FS，迁移目录 `migrations/`（由 `sql/schema/` mirror） |
| `migrations/` | 嵌入式 SQL（与 `server/sql/schema/` 通过 `tools/mirror_schema_to_migrations.py` 同步） |
| `migrate_test.go` | hello SP smoke + 迁移幂等测（env 跳过） |
| `sp_pve_*_test.go` | 各 Round 的 SP 端到端套件（env 跳过） |
| `integration_test.go` | **Round 12 A3 跨 Round canary**（build tag 隔离） |

---

## 单元测试（默认）

```bash
cd server/src
go test -count=1 ./internal/database/...
```

不需要 PG。所有需要 PG 的子测都用 `t.Skip()` 自动跳过。

---

## PG 集成测试 — Round 12 A3 canary

**6 个 canary**：每个 Round 选一个有代表性 SP，专门检查 SP 签名漂移。
用 `//go:build integration` tag 隔离，默认 `go test ./...` 不跑。

```bash
PGTEST_DSN="postgres://postgres:postgres@127.0.0.1:5432/aion_world_live?sslmode=disable" \
  go test -tags=integration ./internal/database/... -count=1 -v
```

清理 band：`char_id 9_080_000..9_080_099` + `instance_id 9_580_000..9_580_099`。

涵盖 SP：

| Round | SP | 验证点 |
|-------|----|---|
| R8 housing | `aion_PutHouseInstant` + `aion_GetHouseInstant` | 写入后 join user_data 读回 owner |
| R8 pet | `aion_PutPetNew2` + `aion_GetPetListNew2` | BIGSERIAL id + 列表查询 |
| R9 instance | `aion_SetUserInstance` + `aion_GetUserInstance` | 6-arg variant |
| R9 condition | `aion_SetInstanceCondition` | INSERT + UPDATE 双分支幂等 |
| R9 monster | `aion_SetMonsterAchievement` + `aion_GetMonsterAchievementList` | 写读 |
| R10 char | `aion_SetCharDeleteTime` + `aion_ClearCharDeleteTime` | 软删 + 还原 |

**为什么这样设计**：业务正确性已由 `sp_pve_round{6..10}_test.go` 全覆盖。
canary 套件只验"SP 签名匹配 + 真打到 PG 不报错"，CI 跑得快、易于诊断。

---

## 全 Round 集成测试（历史套件）

老的 `sp_pve_*_test.go` / `sp_char_lifecycle_test.go` 走另一组 env：

```bash
AION_TEST_PG_HOST=127.0.0.1 \
AION_TEST_PG_PORT=5432 \
AION_TEST_PG_DB=aion_world_live \
AION_TEST_PG_USER=postgres \
AION_TEST_PG_PASS=postgres \
  go test -count=1 -v ./internal/database/...
```

未设 env → `t.Skip()`。

---

## 本地 PG 准备（一次性）

Windows 安装的 PostgreSQL 服务默认端口 5432。库 `aion_world_live` 由 goose
自动迁移到 v129（截至 Round 11）。如果版本号 < 129，运行 canary 时
`Migrate()` 会自动 catch up。

如果你的本地凭据不是 `postgres/postgres`，相应改 DSN：

```bash
PGTEST_DSN="postgres://USER:PASS@127.0.0.1:5432/aion_world_live?sslmode=disable" \
  go test -tags=integration ./internal/database/... -v
```

---

## CI 接线

参见 `.github/workflows/ci.yml` —— `test-integration` job 在 ubuntu runner
里启 PG 服务 + 跑 canary 套件，作为 lint/build/test-unit 之后的最终 gate。

---

## 本地 pre-commit hook（可选）

`ACE_5.8/server/tools/pre-commit-hook.sh` 跑 vet + mirror-check + go test (60s)。
不强制安装；想接入：

```bash
# 在仓库根目录 D:/拾光ai/ 跑
ln -sf "$PWD/ACE_5.8/server/tools/pre-commit-hook.sh" .git/hooks/pre-commit
```

跳过单次提交：`git commit --no-verify`。
卸载：`rm .git/hooks/pre-commit`。
