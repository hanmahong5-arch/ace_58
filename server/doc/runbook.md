# AionCore 5.8 操作 Runbook

> **适用场景**：上线后值班 / 服务异常 / 中间件故障  
> **目标**：3am page 时，5 分钟内定位 + 处置  
> **每条 entry 必含**：症状 → 诊断命令 → 处置步骤 → 验证恢复  
> **配套文档**：[`./architecture.md`](./architecture.md) · [`./dev-boot-checklist.md`](./dev-boot-checklist.md) · [`./observability.md`](./observability.md) · [`./incident-response.md`](./incident-response.md)

---

## 快速诊断 / Quick Triage

| 现象 | 先看 entry | 一句话诊断 |
|------|------------|-----------|
| client 连不上 :2108 / :2208 | [E1](#e1--gateway-不接-client-连接) | gateway 进程 / 端口 |
| world 突然消失日志 | [E2](#e2--world-进程崩溃--panic) | world panic / OOM |
| `psql` 也连不上 | [E3](#e3--postgresql-不可达) | PG 服务 / 磁盘 |
| `redis-cli ping` 超时 | [E4](#e4--redis--devredis-disconnect) | Redis 进程 |
| 玩家"延迟很大"但没断线 | [E5](#e5--nats-jetstream-lag) | NATS lag |
| Lua 调用全部 hang | [E6](#e6--vmpool-耗尽lua-acquire-vm-超时) | VM 池漏 |
| 卡在角色列表 | [E7](#e7--玩家上线失败cm_auth-通过但卡-cm_character_list) | NATS player.enter 链 |
| 改 Lua 不生效 | [E8](#e8--hot-reload-失败--lua-syntax-error) | fsnotify / parse |
| 启动报 migration error | [E9](#e9--migration-失败goose-embed-up-报错) | sql/schema goose |
| Grafana 拉不到指标 | [E10](#e10--telemetry-endpoint-9090-不响应) | metrics server |
| 一片玩家集体掉线 | [E11](#e11--大批量玩家断线--集体丢包) | 网络 / gateway accept loop |
| 副本 cooldown 不对 | [E12](#e12--副本instancerun_id-错乱--cooldown-黑卡) | jobq / SP |

> ⚠️ **第一原则**：先 `make verify-middleware` 确认中间件健康，再看具体 service。**60% 的"服务挂了"实际上是 PG/Redis/NATS 挂了**。

## E1 — Gateway 不接 client 连接

**端口**：dev `:2208` / prod `:2108`（auth）+ dev `:7877` / prod `:7777`（game）

### 症状
- client 报 `connection refused` / RST / 长超时
- launcher 卡在"正在连接服务器…"
- `tinyclient` 报 `connect auth: dial tcp 127.0.0.1:2108: connectex: No connection could be made`

### 诊断（按顺序跑）
```bash
cd D:/拾光ai/ACE_5.8/server

# 1. 中间件健康？
make verify-middleware

# 2. gateway 进程在不在
tasklist | grep -i gateway.exe

# 3. gateway 端口监听？
netstat -an -p tcp | grep -E "(:2108|:7777) " | grep LISTENING

# 4. gateway 最近 50 行日志
tail -50 logs/gateway.log
```

### 处置（按概率排序）

1. **gateway 进程不存在** → `make stop && make boot`，看 `logs/gateway.log` 启动是否成功。
2. **gateway 起了但端口未 LISTENING** → 大概率端口被占。`netstat -ano | grep 2108` 拿 PID，`taskkill //F //PID <pid>` 后重启。
3. **gateway 起了 + 监听但日志在 panic** → 看 panic stack。常见：PG 不可达（→ E3）、RSA pem 文件丢失（`config/rsa_private.pem`）。
4. **firewall 拦截**：Windows Defender Firewall → 入站规则放行 `gateway.exe`。
5. **配置端口和 client 不一致** → `config/gateway.toml` 的 `[auth] port` 与 launcher 启动参数对齐。

### 验证恢复
```bash
make boot-test
# 期望：tinyclient: end-to-end OK elapsed=~110ms
```

---

## E2 — World 进程崩溃 / panic

### 症状
- 玩家在线突然全部"卡住不动"，但仍连接（gateway 还活）
- `tasklist | grep world.exe` 无输出
- `logs/world.log` 末尾出现 `panic:` 或 `runtime error:`

### 诊断
```bash
# 进程是否存活
tasklist | grep -i world.exe

# panic 堆栈
tail -200 logs/world.log | grep -A 30 -E "(panic:|runtime error:|fatal error:)"

# 最近 SP 调用 / NATS 订阅信息
tail -300 logs/world.log | grep -iE "(sp_name|nats|jetstream)"
```

### 处置

1. **panic 是 nil pointer / index out of range** → 多半是新合的 Lua 脚本边界错。
   ```bash
   # 拉黑最近改的 Lua（看 git diff scripts/）
   git -C D:/拾光ai/ACE_5.8/server log --since="2 hours ago" --name-only -- scripts/
   # 临时回滚某个文件
   git -C D:/拾光ai/ACE_5.8/server checkout HEAD~1 -- scripts/handlers/<bad_file>.lua
   ```
2. **panic 是 PG 相关** → 跳到 E3。
3. **panic 是 OOM (`runtime: out of memory`)** → 内存泄漏。先重启续命，归档 `logs/world.log` 到 `logs/incident-<date>.log`，再看 VMPoolSize 指标历史走势（→ E6）。
4. **重启 world 单进程**：
   ```bash
   taskkill //F //IM world.exe
   cd D:/拾光ai/ACE_5.8/server
   AIONCORE_CONFIG_DIR=$PWD/config nohup bin/world.exe > logs/world.log 2>&1 &
   ```

### 验证恢复
```bash
tail -f logs/world.log
# 期望: Lua 87 脚本预编译 OK / NATS 订阅 player.enter OK
make boot-test
```

---

## E3 — PostgreSQL 不可达

### 症状
- gateway / world 启动即 panic：`failed to connect: dial tcp 127.0.0.1:5432`
- 玩家登录卡 `SM_LOGIN_FAIL reason=0xFE`（数据库错误）
- `psql -h 127.0.0.1 -U postgres` 也失败

### 诊断
```bash
# 服务状态
sc query postgresql-x64-16

# 端口监听
netstat -an -p tcp | grep ":5432 " | grep LISTENING

# 直连测试
psql -h 127.0.0.1 -U postgres -d aion_world_live -c "SELECT 1;"

# 数据目录磁盘占用
df -h /c
```

### 处置

1. **服务停止** → `net start postgresql-x64-16`（管理员权限）。
2. **服务起了但端口不监听** → PG 启动卡住，看 PG 日志：
   ```bash
   tail -100 "C:/Program Files/PostgreSQL/16/data/log/postgresql-*.log"
   ```
3. **磁盘满** (`No space left on device`)：
   - 立即清 `logs/`：`rm logs/*.log.[0-9]*`
   - 清 PG WAL 归档（如启用）
   - 之后排查归档保留策略
4. **认证失败** (`password authentication failed`)：
   - 检查 `AIONCORE_DB_PASS` 环境变量
   - 检查 `pg_hba.conf` 是否仅 `127.0.0.1` 段（**绝不能 `0.0.0.0/0`**，见"千万别这样做"）
5. **连接耗尽** (`too many clients`)：
   - `psql -c "SELECT count(*) FROM pg_stat_activity;"` — 超过 max_connections (默认 100) 即满
   - 临时：`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state='idle' AND now()-state_change > interval '10 minutes';`
   - 长期：调 `postgresql.conf` `max_connections=300`，或排查 pgxpool leak

### 验证恢复
```bash
psql -h 127.0.0.1 -U postgres -d aion_world_live -c "SELECT count(*) FROM pg_proc WHERE proname LIKE 'aion_%';"
# 期望: 数百行（已迁移的 SP）
make boot-test
```

---

## E4 — Redis / devredis disconnect

### 症状
- gateway 颁发 token 失败：`session write: dial tcp 127.0.0.1:6379`
- `tinyclient` 卡在 `read SM_PLAY result: timeout`
- 玩家从 :2108 切到 :7777 后立刻断线

### 诊断
```bash
# 进程
tasklist | grep -i devredis.exe

# 端口
netstat -an -p tcp | grep ":6379 " | grep LISTENING

# ping
redis-cli -h 127.0.0.1 ping
# 或（无 redis-cli）:
echo -e "PING\r\n" | nc 127.0.0.1 6379
```

### 处置

1. **devredis 进程没了** → Makefile 自动重启：
   ```bash
   make boot
   # 或单独:
   nohup tools/devredis/devredis.exe > logs/devredis.log 2>&1 &
   ```
2. **端口被别的 redis 占** → `netstat -ano | grep :6379` 找 PID。如果是别的 redis 实例，检查 prod/dev 配置端口冲突（dev 应用 DB 2/3，prod 用 DB 0/1，`config/gateway.toml` 的 `[redis] db` 字段）。
3. **数据丢失（devredis 是 miniredis，重启即清）** → 这是预期行为；session token 也是短 TTL，玩家重登即可。生产如真上 redis-server 持久化，再考虑 RDB/AOF 恢复。

### 验证恢复
```bash
redis-cli -h 127.0.0.1 ping  # → PONG
make boot-test
```

---

## E5 — NATS JetStream lag

### 症状
- `aion_nats_lag_seconds` Prometheus 指标 > 1（observability.md 报警阈值）
- 玩家"技能延迟"——按下技能 1-3 秒后才生效
- world 日志大量 `nats: slow consumer detected`

### 诊断
```bash
# 进程
tasklist | grep -i nats-server.exe

# 监控 endpoint（如开启 -m）
curl -s http://127.0.0.1:8222/jsz?streams=true 2>/dev/null

# Prometheus 拉
curl -s http://127.0.0.1:9090/metrics | grep aion_nats_lag_seconds

# NATS 自己的 log
tail -100 logs/nats.log
```

### 处置

1. **lag 是因为 world 处理太慢**（最常见）→ 不是 NATS 问题，是 world VMPool / SP latency 问题。先看 E6 + observability `aion_sp_latency_seconds`。
2. **NATS 内存吃满** → JetStream 默认全内存，stream 数据堆积可吃光。
   ```bash
   curl -s http://127.0.0.1:8222/varz | grep -iE "(mem|connections)"
   ```
   临时方案：`make stop && make boot`（重启清 stream；玩家会被踢，上线后通知）。
3. **多 consumer 抢同一 subject** → 检查 world / chat 是否重复订阅同一个 subject（不应该）。`internal/ipc/` 下 subject 命名约定。
4. **磁盘满（如开了 file-storage）** → 同 E3 磁盘排查。

### 验证恢复
```bash
# lag 应回到 < 0.1
curl -s http://127.0.0.1:9090/metrics | grep aion_nats_lag_seconds
```

---

## E6 — VMPool 耗尽（Lua acquire VM 超时）

### 症状
- world 日志：`vmpool: acquire timeout after 5s`
- 玩家"技能不响应"，反复点也没反应
- `aion_vm_pool_size` 指标长时间为 0

### 诊断
```bash
# Pool 当前大小
curl -s http://127.0.0.1:9090/metrics | grep aion_vm_pool_size

# Lua handler latency 是否爆涨
curl -s http://127.0.0.1:9090/metrics | grep aion_lua_call_latency_seconds | head -10

# world 日志中最长的 Lua 调用
tail -500 logs/world.log | grep "lua_call" | sort -k 4 -n | tail -10
```

### 处置

1. **某个 Lua handler 死循环 / 阻塞 IO** — 最常见。
   - 看哪个 `fn_name` latency 离群：`aion_lua_call_latency_seconds_bucket{fn_name="..."}` p99
   - 临时回滚那个脚本（git checkout 回上个 commit）
2. **VM 没释放回 pool**（bridge defer 漏了）→ Go 代码 bug；只能重启 world。归档现场：
   ```bash
   curl -s http://127.0.0.1:9090/metrics > logs/metrics-snapshot-$(date +%Y%m%d_%H%M%S).txt
   tail -1000 logs/world.log > logs/world-snapshot-$(date +%Y%m%d_%H%M%S).log
   ```
3. **池容量配的太小** → `config/world.toml` 的 `[lua] vm_pool_size`，dev 默认 8，prod 建议 32+。改完热重载（fsnotify 监听）。

### 验证恢复
```bash
# 池大小回升 + handler latency 回到 < 10ms p99
curl -s http://127.0.0.1:9090/metrics | grep -E "(aion_vm_pool_size|aion_lua_call_latency_seconds)"
```

---

## E7 — 玩家上线失败（CM_AUTH 通过但卡 CM_CHARACTER_LIST）

### 症状
- 客户端 :2108 握手 OK，跳到 :7777 后**没收到角色列表**就超时
- `tinyclient` 报 `await first SM after CM_SESSION_CONFIRM: timeout`

### 诊断（按数据流逆向）
```bash
# 1. gateway 是否发 NATS player.enter
tail -200 logs/gateway.log | grep -i "player.enter"

# 2. world 是否收到
tail -200 logs/world.log | grep -i "player.enter"

# 3. world 调 SP 是否成功
tail -200 logs/world.log | grep -iE "(aion_get_character_list|SM_CHARACTER_LIST)"

# 4. NATS 本身健康
curl -s http://127.0.0.1:8222/jsz 2>/dev/null
```

### 处置

1. **gateway 收 token 但 world 没收到事件** → NATS 连接断（看 gateway/world 各自 NATS 重连日志）。`make stop && make boot` 强制全链路重连。
2. **world 收到事件但 SP 调失败** → PG 那一侧问题（→ E3）；或 SP 不存在（看 `psql -c "\df aion_get_character_list"`）。
3. **Lua `cm_character_list.lua` 报错** → 看 world.log 中 `[ERROR] lua handler` 行。
4. **Token 已过期/不匹配** → Redis 中 `session:<token>` 已 TTL 过期。提醒玩家重登；如频发查 Redis 健康（→ E4）。

### 验证恢复
```bash
make boot-test
# 期望末行: tinyclient: end-to-end OK
```

---

## E8 — Hot-reload 失败 / Lua syntax error

### 症状
- 改了 `scripts/**/*.lua`，1 秒内**没**生效
- world 日志：`lua: load: ... syntax error near '...'`
- 老脚本继续运行（fsnotify 检测到但 parse 失败 → 拒绝 swap）

### 诊断
```bash
# 最近的 reload log
tail -100 logs/world.log | grep -iE "(reload|fsnotify|lua: load)"

# 手动语法检查（用 luac 或 gopher-lua 单测）
cd src && go test ./internal/luahost/ -run TestLuaSyntax -v
```

### 处置

1. **看错误行 + 修语法**（最常见：`then`/`end` 漏写、字符串引号不闭合、UTF-8 BOM）。
2. **fsnotify 没触发** → 文件系统事件丢失（Windows 上 git 操作有概率丢）。`touch scripts/handlers/<file>.lua` 强制触发。
3. **circular require** → Lua module 之间循环依赖；改成 lazy require（在函数内 require 而非顶层）。
4. **reload 成功但行为不对** → 检查 module-level table 是否有 stale state；按 architecture.md §6 约束：状态须放 ECS / Redis，不放 module table。

### 验证恢复
```bash
# 触发一次 trivial 改动验证 reload
echo "-- reload trigger $(date)" >> scripts/handlers/<file>.lua
tail -f logs/world.log | grep -i reload
# 期望: "lua reload OK ..." 1 秒内出现
```

---

## E9 — Migration 失败（goose embed up 报错）

### 症状
- world 启动即 fatal：`goose: failed to run migration ...`
- `sql/schema/00NNN_xxx.sql` 新加的文件触发

### 诊断
```bash
# world 启动前 30 行
head -100 logs/world.log

# 当前 migration 版本
psql -h 127.0.0.1 -U postgres -d aion_world_live -c "SELECT * FROM goose_db_version ORDER BY id DESC LIMIT 5;"

# 列出 schema 文件
ls sql/schema/
```

### 处置

1. **SQL 语法错** → 看具体 migration 文件的报错行。手工在 `psql` 里逐句跑确定哪句挂。
2. **某条 migration 部分提交了**（PG 不支持 DDL 事务的少数语句）→ `goose_db_version` 没记录，但 schema 已部分变更：
   ```sql
   -- 找出已经存在的对象，手工补 INSERT
   INSERT INTO goose_db_version (version_id, is_applied) VALUES (NNN, true);
   ```
3. **依赖前置 migration 漏跑** → embed migrations 是顺序的；检查 `00132_..` 是否已应用：
   ```sql
   SELECT * FROM goose_db_version WHERE version_id BETWEEN 130 AND 140 ORDER BY version_id;
   ```
4. **回滚某条 migration**：
   ```bash
   # 仅在确认无玩家数据依赖时
   cd src && go run ./internal/database/cmd/goose -dir migrations down
   ```
   ❌ **生产环境禁止盲 down**——见"千万别这样做"。

### 验证恢复
```bash
psql -c "SELECT max(version_id) FROM goose_db_version;"
# 应等于 sql/schema/ 最大编号
make boot-test
```

---

## E10 — Telemetry endpoint :9090 不响应

### 症状
- Grafana scrape 报 `connection refused 127.0.0.1:9090`
- `curl http://127.0.0.1:9090/metrics` 超时

### 诊断
```bash
netstat -an -p tcp | grep ":9090 " | grep LISTENING
curl -v http://127.0.0.1:9090/healthz
tail -50 logs/world.log | grep -i metrics
```

### 处置

1. **没启 metrics server** → 检查 main 是否调 `telemetry.RunServer(...)`（observability.md §"接入示例"）。修代码 + rebuild + restart。
2. **9090 被 Prometheus 自己占了**（同机部署）→ 改 world 进程的 metrics 端口为 9091（observability.md §"端点设计"已建议）。修 `config/world.toml`。
3. **healthz 200 但 /metrics 报错** → registry collector panic；归档 panic 日志后重启进程。

### 验证恢复
```bash
curl -s http://127.0.0.1:9090/metrics | head -20
# 期望: # HELP / # TYPE 注释 + aion_* 指标行
```

---

## E11 — 大批量玩家断线 / 集体丢包

### 症状
- 同一时间窗（30 秒内）大批玩家被踢
- gateway log 大量 `connection closed by peer` / `write: broken pipe`
- 群里炸锅

### 诊断
```bash
# 当前活跃连接
netstat -an -p tcp | grep -E "(:2108|:7777|:2208|:7877) " | grep ESTABLISHED | wc -l

# 最近的 disconnect 风暴
tail -1000 logs/gateway.log | grep -iE "(disconnect|broken pipe|reset by peer)" | tail -50

# 系统负载
tasklist /v | grep -iE "(gateway|world)" | awk '{print $1, $5, $8}'

# 网卡是否丢包（Windows）
netsh int ipv4 show ipstats
```

### 处置

1. **网络抖动 / 上游运营商问题** → 看玩家 IP 段是否集中（同一 ISP）。无法处置，发公告。
2. **gateway accept 队列满** → `config/gateway.toml` 的 `accept_backlog` 调高（默认 128 → 1024）。
3. **PG / Redis 一时不可达**（→ E3/E4）触发雪崩 → 修中间件后玩家可重登。
4. **DDoS / 异常包** → 看 gateway log 是否有 `malformed packet` 风暴。临时上 firewall 限速：
   ```bash
   # Windows: 限制单 IP 连接数（仅紧急用）
   netsh advfirewall firewall add rule name="aion-rate-limit" dir=in protocol=TCP localport=2108 action=allow remoteip=any profile=any
   ```
5. **运营商大区故障** → 切备用 IP（如有）。无 → 发公告。

### 验证恢复
```bash
# 5 分钟后看连接数回升 + 没有新 disconnect 风暴
netstat -an -p tcp | grep -E "(:2108|:7777) " | grep ESTABLISHED | wc -l
```

---

## E12 — 副本（Instance）run_id 错乱 / cooldown 黑卡

### 症状
- 玩家明明没进副本，但显示 cooldown 中
- 队伍中有人能进、有人不能进
- 副本到期未清理（jobq `aion58.instance.expire` 失败）

### 诊断
```bash
# 玩家的 instance cooldown 表
psql -d aion_world_live -c "SELECT char_id, instance_id, expiretime FROM aion_player_instance_cd WHERE char_id=<CHAR_ID>;"

# jobq 里待处理 / 失败的 instance.expire 任务
redis-cli -h 127.0.0.1 KEYS "asynq:*instance.expire*"

# world 日志中的副本相关
tail -500 logs/world.log | grep -iE "(instance|run_id)"
```

### 处置

1. **玩家被错卡 cooldown** → 用 GM SP 清单条记录：
   ```sql
   CALL aion_clear_user_instance(<char_id>, <instance_id>);
   ```
2. **jobq 卡死** → 看 asynq dashboard（如有）或 Redis 里失败队列：
   ```bash
   redis-cli -h 127.0.0.1 LRANGE asynq:retry 0 -1
   ```
   重新 enqueue 单条任务（参考 `internal/jobq/workers.go`）。
3. **run_id 互相覆盖** → 多半是创建副本时 leader_eid 被复用（重登触发）。bug 必复现的话归档玩家操作序列 + 时间，提 issue。临时 workaround：让玩家退队再重新组。

### 验证恢复
```bash
# cooldown 表干净 + 玩家能正常进副本
psql -c "SELECT count(*) FROM aion_player_instance_cd WHERE expiretime < now();"
# 期望: 0（已过期的应被 jobq 清掉）
```

---

# 附录 / Appendix

## A. 命令速查 / Command Cheatsheet

```bash
cd D:/拾光ai/ACE_5.8/server   # 永远从这开始

# Boot / 健康
make boot                # 启动 5 服务 + NATS + devredis
make boot-test           # boot + tinyclient 端到端
make verify-middleware   # 检查 PG/NATS/Redis 端口
make stop                # 停 5 服务 + 中间件（不动 PG）
make test / make cover   # 单测 / 覆盖率

# 进程 / 端口
tasklist | grep -iE "gateway|world|chat|logd|admin|nats|devredis"
netstat -an -p tcp | grep -E "(:2108|:7777|:5432|:4222|:6379|:9090) " | grep LISTENING
netstat -ano | grep <pid>                 # 反查 pid 占用端口
taskkill //F //IM <name>.exe

# PG
sc query postgresql-x64-16   # net start postgresql-x64-16 启动
psql -h 127.0.0.1 -U postgres -d aion_world_live
# SQL: SELECT * FROM goose_db_version ORDER BY id DESC LIMIT 5;
# SQL: SELECT count(*) FROM pg_stat_activity;

# Redis / NATS / Telemetry
redis-cli -h 127.0.0.1 ping
curl -s http://127.0.0.1:8222/varz                     # NATS
curl -s http://127.0.0.1:9090/metrics | grep aion_     # Prometheus
curl -s http://127.0.0.1:9090/healthz                  # liveness
```

## B. 日志路径速查 / Log Paths

| 文件 | 内容 |
|------|------|
| `logs/gateway.log` | TCP accept / 握手 / 解密 / NATS 转发 |
| `logs/world.log` | ECS / Lua VM / SP 调用 / jobq |
| `logs/chat.log` | 频道聊天（当前 stub） |
| `logs/logd.log` | 日志聚合（当前 stub） |
| `logs/admin.log` | REST API（当前 stub） |
| `logs/nats.log` | NATS server |
| `logs/devredis.log` | miniredis |
| `C:/Program Files/PostgreSQL/16/data/log/postgresql-*.log` | PG（不在仓库内） |

> 归档现场：`cp logs/world.log logs/incident-$(date +%Y%m%d_%H%M%S)-world.log`

## C. 端口速查 / Port Map

| 端口 (dev) | 端口 (prod) | 进程 | 用途 |
|------------|------------|------|------|
| 2208 | **2108** | gateway | Auth / CM_AUTH_LOGIN |
| 7877 | **7777** | gateway | Game / 主战斗 |
| 10241 | 10241 | chat | 频道聊天（stub） |
| 8080 | 8080 | admin | REST + Web（stub） |
| 9090 | 9090 | world (metrics) | Prometheus scrape |
| 4222 | 4222 | nats-server | JetStream |
| 8222 | 8222 | nats-server | monitor HTTP |
| 6379 | 6379 | devredis | session / jobq |
| 5432 | 5432 | postgres | 4 库 + 1314 SP |

## D. 千万别这样做 / Hard Don'ts

> 这些操作在生产环境会**直接丢钱 / 丢数据 / 丢玩家**。值班时若不确定，先停手联系作者。

- ❌ `pg_hba.conf` 写 `host all all 0.0.0.0/0 md5` — **2026-04-11 勒索教训**，PG 永远 127.0.0.1 only
- ❌ `rm -rf D:/拾光ai/ACE_5.8/server/` 在没确认 git push 的情况下
- ❌ `kill -9` 正在跑 migration 的 world 进程（goose 状态可能半提交）
- ❌ 用 `go build -tags release` 上 prod — 本仓库**只做 debug 构建**（global CLAUDE.md 规定）
- ❌ 在 Go 或 Lua 里写裸 `INSERT/UPDATE/DELETE` SQL — 必须走 SP
- ❌ 盲跑 `goose down` 在生产 — 数据列删除不可逆
- ❌ 把 `config/rsa_private.pem` 提交到 git — 客户端会用对应 pubkey，私钥换了所有玩家无法登录
- ❌ 在生产 `taskkill //F //IM postgres.exe` — Windows SCM 会重启但 WAL 可能 corrupt
- ❌ 改 `opcodes.go` 里**已分配**的 opcode 数值 — 客户端 hardcode，不匹配即玩家全部断线
- ❌ 在玩家在线时 `make stop` 不发公告 — 至少提前 60 秒发，参考 incident-response.md §沟通模板
- ❌ Redis `FLUSHALL` 在生产 — 所有 session token 失效，玩家集体掉线（强制重登）
- ❌ 给某玩家 GM 物品时直接 `INSERT INTO inventory` — 会绕过 SP 内的物品 ID 序列，**永久破坏物品系统**

## E. 升级到 Incident Response

如果出现以下情况之一，立即按 [`./incident-response.md`](./incident-response.md) 流程办：

- 全服 down > 5 分钟（P0）
- 任何玩家资产丢失（P0）
- 单 service 异常超过 30 分钟未恢复（P1）
- 中间件被攻击 / 入侵迹象（P0）
- 数据库出现 `corruption` / `checksum failed` 字样（P0）
