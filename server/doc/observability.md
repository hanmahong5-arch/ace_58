# Observability — Prometheus 接入指南

> AionCore 5.8 自动化指标埋点。本期交付库 (`internal/telemetry`)，调用方按需接入。

## 为什么需要这个

5.8 私服上线即"黑盒"——没有指标 = 没有诊断 = 故障扩大到玩家投诉才暴露。
Prometheus 是 cloud-native 的事实标准，免费开源，能跟 Grafana / Alertmanager 无缝串联。

**核心命题**：服务进程必须**主动暴露**自己的状态，而不是被动等运维去 SSH 看日志。

我们的最小可行集 (MVP)：

- **8 个核心指标** 覆盖玩家 / 协议 / SP / Lua / 后台任务 / NATS 全链路
- **零全局状态** — 每个进程持有独立 registry，单元测试天然 hermetic
- **非侵入** — 库不"魔改" cmd/world/main.go，调用方手动接入 (5 行代码)

---

## 端点设计

| 路径        | 用途                       | 行为 |
|-------------|----------------------------|------|
| `/metrics`  | Prometheus 抓取入口        | 文本格式 (OpenMetrics-aware)，registry-bound |
| `/healthz`  | k8s/系统级 liveness probe  | 返回 200 + `ok\n`，**不依赖 registry**（即使指标 collector panic 也保持绿） |

**默认端口约定**：`:9090`（Prometheus 生态默认端口，避免和 gateway 2108 / world 7777 / admin 8080 冲突）。

可独立部署 Prometheus + Grafana，scrape 配置示例：

```yaml
# prometheus.yml
scrape_configs:
  - job_name: aion-gateway
    static_configs:
      - targets: ['127.0.0.1:9090']
        labels: { service: gateway }
  - job_name: aion-world
    static_configs:
      - targets: ['127.0.0.1:9091']
        labels: { service: world }
```

---

## 接入示例 (cmd/world/main.go 伪代码)

下面是把 `internal/telemetry` 接入 5 个进程任意一个的标准三步：

```go
import (
    "context"
    "log/slog"

    "github.com/prometheus/client_golang/prometheus"
    "aion58/internal/telemetry"
)

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    logger := slog.Default()

    // 1. 创建 registry + 注册全部 collector
    reg := telemetry.NewRegistry()
    metrics := telemetry.New(reg)

    // 2. 后台启动 metrics HTTP server (ctx 取消时优雅停止)
    go func() {
        if err := telemetry.RunServer(ctx, ":9090", reg, logger); err != nil {
            logger.Error("metrics server died", "err", err)
        }
    }()

    // 3. 在业务热路径埋点 ↓↓↓
    //
    // 玩家进入 zone:
    metrics.PlayerCount.WithLabelValues(zoneID).Inc()
    // 玩家离开:
    metrics.PlayerCount.WithLabelValues(zoneID).Dec()
    //
    // 协议包进出 (gateway):
    metrics.PacketsTotal.WithLabelValues("cm", "0x4B").Inc()
    metrics.PacketsTotal.WithLabelValues("sm", "0x12").Inc()
    //
    // SP 调用 (用 Timer 自动计时):
    timer := prometheus.NewTimer(metrics.SPLatencySeconds.WithLabelValues("aion_get_char_id_by_name"))
    _, err := pool.Exec(ctx, "CALL aion_get_char_id_by_name($1)", name)
    timer.ObserveDuration()
    //
    // Lua handler 调用:
    timer = prometheus.NewTimer(metrics.LuaCallLatencySeconds.WithLabelValues("on_player_enter"))
    err = vmpool.CallGlobal("on_player_enter", playerID)
    timer.ObserveDuration()
    //
    // VMPool 容量 (周期性更新，建议 5s 心跳):
    metrics.VMPoolSize.Set(float64(vmpool.PoolLen()))
    //
    // 后台任务:
    metrics.JobsEnqueuedTotal.WithLabelValues("level_up_reward").Inc()
    metrics.JobsCompletedTotal.WithLabelValues("level_up_reward", "ok").Inc()
    //
    // NATS lag (从 JetStream consumer info 周期性拉):
    metrics.NATSLagSeconds.Set(lagSec)
}
```

> ⚠️ **不要把 `prometheus.NewTimer + ObserveDuration` 放在 `defer` 里**——
> 如果调用经常返回 error 但又被 retry，defer 把多次 retry 算成一次大 latency。
> 显式 `timer.ObserveDuration()` 更清晰。

---

## 全部指标清单

| 指标名                            | 类型      | 标签                     | 含义 |
|-----------------------------------|-----------|--------------------------|------|
| `aion_player_count`               | GaugeVec  | zone                     | 当前在线玩家数（按 zone 分） |
| `aion_packets_total`              | CounterVec| direction, opcode_hex    | 协议包累计计数（cm=client→server，sm=server→client） |
| `aion_sp_latency_seconds`         | Histogram | sp_name                  | PG SP 调用耗时分布（buckets: 1ms..1s） |
| `aion_lua_call_latency_seconds`   | Histogram | fn_name                  | Lua 入口函数调用耗时（buckets: 100µs..100ms） |
| `aion_vm_pool_size`               | Gauge     | —                        | 当前已预热的 Lua VM 数 |
| `aion_jobs_enqueued_total`        | CounterVec| kind                     | 后台任务入队累计 |
| `aion_jobs_completed_total`       | CounterVec| kind, status (ok\|err)   | 后台任务完成累计 |
| `aion_nats_lag_seconds`           | Gauge     | —                        | NATS JetStream 消费者滞后（pub_ts − deliver_ts） |

**命名约定**：
- 前缀 `aion_` — 多 exporter 部署时按 namespace 区分
- 计数器后缀 `_total` — Prometheus 客户端规范
- 时间单位后缀 `_seconds` — OpenMetrics 强制基础 SI 单位（不要用 `_ms`）

---

## Cardinality 控制（**必读**）

Prometheus 为**每个 label-value 组合**建独立时间序列，永久存储。
不当 label = 静默内存泄漏 = 抓取端 OOM。

### 允许的 label（已验证有界）

| label        | 取值上限 | 来源 |
|--------------|----------|------|
| `zone`       | ~50      | 5.8 worldid 表 |
| `direction`  | 2        | cm / sm |
| `opcode_hex` | ~80      | `internal/aionproto/opcodes.go` |
| `sp_name`    | ~150     | 1314 SP 中热路径 ~150 个 |
| `fn_name`    | ~50      | Lua 入口 (handlers/events/skills 命名表) |
| `kind`       | ~30      | jobq 注册的 worker kind |
| `status`     | 2        | ok / err |

### 禁止的 label

任何随玩家/请求/时间增长的字段，绝对不能做 label：

- ❌ `char_id` / `player_name` / `account_id`（每个玩家一条 series）
- ❌ `ip_address`（每个 IP 一条）
- ❌ `request_id` / `trace_id`（无穷无尽）
- ❌ `packet_payload` / `sql_text` / `error_message`（高熵）

需要这些信息？写到 **日志**（slog → logd → ClickHouse）或 **trace**（OpenTelemetry，未来），不要进 Prometheus。

---

## 测试 / 验证

```bash
cd D:/拾光ai/ACE_5.8/server/src
go test ./internal/telemetry/... -count=1 -v
```

预期：4 PASS。

手动 smoke：

```bash
# 起一个最小 demo 进程，curl 验证
curl -s 127.0.0.1:9090/metrics  | head -20
curl -s 127.0.0.1:9090/healthz  # → ok
```

---

## 后续工作（不在本期）

- **Grafana dashboard JSON** — 单独 PR；建议看板：
  1. 玩家在线 + zone 分布（heatmap）
  2. 协议吞吐 + opcode TOP10（bar chart）
  3. SP latency p50/p95/p99（histogram quantile）
  4. Lua handler latency p99（同上）
  5. NATS lag + jobq 在飞数（subtract counter）

- **Alertmanager 规则** — 至少配三条：
  - `aion_sp_latency_seconds:p99 > 0.1` 持续 5min → warning
  - `aion_nats_lag_seconds > 1` 持续 1min → critical
  - `aion_player_count{zone="login"}` 突降 50% → critical（疑似 gateway 故障）

- **OpenTelemetry trace 接入** — 跨 5 进程的请求链路追踪；与 Prometheus 互补，不替代。

- **客户端侧指标** — launcher / version-dll 上报需要单独通道（不能直连 Prometheus），考虑通过 admin REST 中转。

---

## 日志管道：slog → NATS → logd → ClickHouse（R5 swarm 实装）

> 上一节讲指标（Prometheus pull），本节讲日志（NATS push + logd 批量入库）。
> 二者解耦：指标侧抓不到时不影响日志，反之亦然。

### 端到端拓扑

```
gateway/world/chat/admin   ─┐
   slog.Logger              │  Publish(subject=log.<service>, JSON line)
   └─ NATSHandler ──────────┼──▶  NATS JetStream (stream=LOGS, MaxAge=1h, MaxBytes=512MB)
                            │       ▲
                            │       │ ExplicitAck + DeliverNew
                            │       │
   logd ◀──────────────────┘       │
   └─ jetstream.Consume ────────────┘
       └─ batcher (1000 条 OR 5s) ──▶  ClickHouse log_events (TTL 30d)
```

### NATSHandler（`internal/telemetry/sloghandler.go`）

每个 5 进程把自己的 `slog.Logger` 封一层 `NATSHandler`，特性：

- **异步**：`slog.Record` 序列化后入 chan，worker goroutine 单独 Publish。**热路径不阻塞**。
- **背压安全**：chan 满时直接丢弃 + 自增 `aion_slog_dropped_total`。日志不能把游戏 tick 拖死。
- **递归保护**：handler 内部错误用 `fmt.Fprintln(os.Stderr)`，**绝不能** 调 `slog.Default()`（自己给自己发消息死循环）。
- **Group/WithAttrs 语义**：实现 `slog.Handler.WithAttrs/WithGroup` — 调用 `logger.With("k", v)` / `logger.WithGroup("conn")` 后产生的 child handler 在序列化时把 group 路径还原成嵌套 JSON。

接入示例（`cmd/world/main.go` 还未注入，预留位）：

```go
import "aion58/internal/telemetry"

pub := nc  // *ipc.Client，本身就是 Publisher（Publish(subject, []byte) error）
nh := telemetry.NewNATSHandler(pub, telemetry.NATSHandlerConfig{
    Service:    "world",
    BufferSize: 4096,
    Workers:    2,
    Level:      slog.LevelInfo,
    AddSource:  true,
})
slog.SetDefault(slog.New(nh))
```

> ⚠️ **R5 swarm 截止时未注入到 gateway/world/chat/admin** — 见 `project_engineering_sweep.md` 第五轮"5 lines waiting for merge" 第 1 项。
> 各进程的 main.go 改造由另一会话路径同步合流后再做（路径互斥避免 git 撞）。

### logd 服务（`cmd/logd/`）

**职责**：JetStream durable consumer + ClickHouse batch writer + 优雅 shutdown。

| 配置项 | 环境变量 | 默认值 |
|--------|---------|--------|
| NATS URL | `NATS_URL` | `nats://127.0.0.1:4222` |
| ClickHouse DSN | `CLICKHOUSE_DSN` | `clickhouse://default@127.0.0.1:9000/aion` |
| Batch 行数阈值 | `LOGD_BATCH_ROWS` | `1000` |
| Batch 时间阈值 | `LOGD_BATCH_AGE` | `5s`（`time.ParseDuration`） |
| Durable 名 | `LOGD_DURABLE` | `logd-main`（多实例必须改） |

**Stream 配置**（`ensureStream` 自动 Create/Update）：

- `Subjects: ["log.>"]`
- `Retention: LimitsPolicy`（按时间 / 字节容量丢）
- `MaxAge: 1h` · `MaxBytes: 512 MB` · `Storage: FileStorage`
- `Discard: DiscardOld`（满了丢老的，**不阻塞 publisher**）

**Consumer 配置**：

- `AckPolicy: ExplicitAck` — 入 batcher 成功才 Ack；失败 Nak 重投；JSON 烂 Term 永久丢。
- `DeliverPolicy: DeliverNewPolicy` — logd 重启从新消息开始，不重放历史（历史已经在 ClickHouse 里）。
- `MaxAckPending: batchRows × 2` — 给 batcher 一倍空间。

**批量落 ClickHouse**：

- 触发条件：`#rows >= 1000` **OR** `now - first_add >= 5s`，**任一先到**。
- Ticker 频率 = `maxAge / 2`（最少 100ms），保证最坏 1.5×maxAge 内一定 flush。
- 失败重投：`PrepareBatch` / `Append` / `Send` 任一报错，整 batch 走 Nak（NATS 重投）。
- Shutdown：SIGINT/SIGTERM 后给 10s 兜底 flush 时间。

### ClickHouse 表（`sql/clickhouse/001_log_events.sql`）

```sql
CREATE TABLE log_events (
    ts       DateTime64(3),
    service  LowCardinality(String),
    level    LowCardinality(String),
    msg      String,
    attrs    String  -- JSON-encoded; query via JSONExtract*
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (service, level, ts)
TTL toDateTime(ts) + INTERVAL 30 DAY;
```

**为什么 `attrs` 用 String 不用 JSON 类型**：跨 ClickHouse 版本兼容（22→24 实现来回改过）；
查询走 `JSONExtractString(attrs, 'char_id')` 即可，对低频查询足够。

**为什么 `ORDER BY (service, level, ts)`**：95% 的查询是"某 service 在某时段的 ERROR/WARN"，
这个排序让 part skip 力度最大。

**TTL 30 天**：私服规模无合规留存需求，自动 drop 旧 part。

### 常用查询模板

```sql
-- 最近 1h 的所有 ERROR
SELECT ts, service, msg, attrs
FROM log_events
WHERE level = 'ERROR' AND ts > now() - INTERVAL 1 HOUR
ORDER BY ts DESC LIMIT 100;

-- 某玩家 char_id 的全链路
SELECT ts, service, level, msg
FROM log_events
WHERE JSONExtractString(attrs, 'char_id') = '12345'
  AND ts > now() - INTERVAL 1 DAY
ORDER BY ts;

-- gateway 错误率（按分钟）
SELECT toStartOfMinute(ts) AS min,
       countIf(level = 'ERROR') AS errs,
       count() AS total
FROM log_events
WHERE service = 'gateway' AND ts > now() - INTERVAL 1 HOUR
GROUP BY min ORDER BY min;
```

### 部署前 smoke 清单

R5 swarm 仅过 `fakeWriter` 单测（CI 不依赖 ClickHouse 容器）。生产前必须：

1. 起 `clickhouse:24-alpine` 容器，建 `aion` 数据库 + 跑 `001_log_events.sql`
2. 起 NATS（已在 `make boot`）
3. 起 logd：`./logd`（默认环境变量都对）
4. 任一进程 `slog.Info("smoke", "k", "v")` 后：
   - `clickhouse-client -q "SELECT count() FROM aion.log_events"` 应增长
   - `aion_slog_dropped_total` 应保持 0（chan 没满）

### 已知限制

- **gateway/world/chat/admin 还没注入 NATSHandler**（路径互斥未合流）
- **logd ClickHouse 写路径只过 fakeWriter**（无真容器冒烟）
- **跨进程 trace_id**：未实装；OpenTelemetry 集成是后续工作
