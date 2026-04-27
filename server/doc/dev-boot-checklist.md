# AionCore 5.8 — 5 进程拓扑 Boot Checklist

> Round-10 F4 产物。验证全部 5 进程 + 中间件 + tinyclient 端到端链路是否打通。
> 配套：`Makefile` (boot-test target)、`src/cmd/tinyclient/`、`bin/proto_simulator.py`。

## TL;DR

```bash
cd D:/拾光ai/ACE_5.8/server
make boot-test
```

成功结束行：

```
time=... level=INFO msg="tinyclient: end-to-end OK" elapsed=~110ms
```

任一失败行立刻停在错误处。

---

## 依赖矩阵

| 组件 | 角色 | 启动方式 | 端口 |
|------|------|---------|------|
| PostgreSQL 16 | 玩家/账号/缓存/GM 四库 + 1314 SP | Windows 服务 `postgresql-x64-16` | 5432 |
| NATS server | gateway↔world IPC（player.login / player.enter / world.sm.*） | `go install github.com/nats-io/nats-server/v2@latest` 后 `nats-server -p 4222` | 4222 |
| devredis (miniredis) | session token 一次性存储 | `cd tools/devredis && go build && ./devredis.exe` | 6379 |
| gateway | 协议网关 (BF-LE/RSA/XOR) | `bin/gateway.exe` | 2108(auth) + 7777(game) |
| world | ECS + Lua VM + jobq | `bin/world.exe` | — (NATS only) |
| chat (stub) | Phase S-3 占位 | `bin/chat.exe` | — |
| logd (stub) | ClickHouse pipeline 未实现 | `bin/logd.exe` | — |
| admin (stub) | REST API 未实现 | `bin/admin.exe` | — |

## 启动顺序（Makefile 自动）

1. **PG** — 假定已作为服务在跑（手工：`net start postgresql-x64-16`）
2. **NATS** — gateway 和 world 都要订阅
3. **devredis** — gateway 颁发 token 时即写
4. **world** — 重，要等 PG migrations + Lua 87 脚本预编译 + 6 张 river 表 ready
5. **gateway** — 此时 world 已在 NATS 订阅 player.enter，gateway 起来后立即可服务
6. **chat / logd / admin** — 顺序无关，stub 永不与他人交互

`make boot` 自动依赖检测 + 跳过已运行项，**不会重复启动**。

## 验证步骤

### 第 1 层：进程都在

```bash
tasklist | grep -iE "nats-server|devredis|gateway|world|chat|logd|admin"
```

期望 7 行（5 服务 + nats + devredis）。PG 是多 worker 进程，单独 grep `postgres`。

### 第 2 层：端口都在监听

```bash
netstat -an -p tcp | grep -E "(:5432|:4222|:6379|:2108|:7777) " | grep LISTENING
```

期望 5 行 LISTENING。

### 第 3 层：握手 + NATS 端到端

```bash
./bin/tinyclient.exe --account shiguang --password hunter2
# 或：
PYTHONIOENCODING=utf-8 python bin/proto_simulator.py --account shiguang --password hunter2
```

成功 = 110-140ms 内收到 `SM_CHARACTER_LIST`。

## 已知坑

### A. dev/ 与 prod/ 子目录不存在

`ACE_5.8/CLAUDE.md` 描述的 `dev/bin/`、`dev/config/` 子目录**当前并未实际生成**。所有二进制 + 配置都在 `server/bin/` + `server/config/` 直接放。Round-10 暂不创建 dev/prod 拆分（避免破坏现有 boot 流），等 Sprint 1 部署阶段再做。

### B. chat/logd/admin 是占位实现

```go
// 它们只 sleep 等 SIGTERM，不打开任何端口、不连任何中间件
```

如果你想"5 进程拓扑全部健康"通过 healthcheck 脚本，**这就是健康的定义**。Phase S-3/S-4 落地后再变成有逻辑的服务。

### C. 已运行 gateway/world 不会被重启

Makefile 用 `tasklist` 检测，避免 kill 用户在跑的会话进程。如需强制更新，先 `make stop` 再 `make boot`。

### D. Windows 上 `&` 后台运行的怪异

git-bash 用 `nohup ... &` 起的后台进程在父 shell 退出后会被 SIGHUP。Makefile 已用 `nohup` 处理；手动 boot 时如发现进程意外退出，看 `logs/<svc>.log` 末尾是否有 SIGHUP/SIGTERM 痕迹。

### E. PG 5432 的 ESTABLISHED 连接堆积

观察到 ~60 个 ESTABLISHED 连接 — 这是 pgxpool 的 idle pool（gateway 10 + world 20 + jobq 复用），正常。如果超过 200 个，怀疑 connection leak。

## 失败定位地图

| tinyclient 报错 | 大概原因 | 检查 |
|-----------------|----------|------|
| `connect auth: dial tcp ... actively refused` | gateway 没起 | `make boot` 重新触发 |
| `read SM_KEY: read header: EOF` | gateway 起了但崩了 | `tail -50 logs/gateway.log` 看 panic |
| `SM_LOGIN_FAIL reason=0x09` | PG `ap_verify_account` 找不到账号 | `psql -c "SELECT login FROM aion_account_db.dbo.gameaccount LIMIT 5"` |
| `read SM_PLAY result: ... timeout` | Redis 没起，token 写失败 | `netstat | grep 6379` |
| `await first SM after CM_SESSION_CONFIRM: timeout` | NATS player.enter 没传到 world，或 world Lua 卡住 | `tail -50 logs/world.log`、`tail logs/nats.log` |

## 与 known-gaps.md 的关系

本 checklist 直接关闭了 known-gaps #6（"NATS IPC not end-to-end"）：
- gateway → NATS (`SubjectPlayerLogin`、`SubjectPlayerEnter`)
- world 订阅 → dispatcher.onPlayerEnter → 拉角色列表 → 回 SM_CHARACTER_LIST
- gateway 转发回 client

每次 `make boot-test` 跑通 = 这条链路依然 healthy。

## 维护节奏

- **每次改 internal/crypto / internal/aionproto / internal/ipc** → 跑一遍 `make boot-test`
- **每天 dev 开机** → `make boot`（自动跳过已运行项）
- **每周一次** → `make stop && make clean && make boot-test`（fresh build 验证）
