# loadgen — AION 5.8 协议级压测工具

## 用途

`loadgen` 用于以**真实 AION 5.8 协议**（BF-LE / RSA-NoPad / XOR seed=1234）施压一台 AionCore gateway，测出在不同稳态并发下：

- **每个握手 phase 的 latency 分布**（p50 / p99）
- **每个 phase 的 error rate**
- **稳态 active session 数**
- **总成功 / 总失败 session 数**

不同于"任意 TCP load"工具（k6 / vegeta / wrk），loadgen 走的是**和 server 共享的代码路径**——`internal/crypto` + `internal/aionproto`，不存在协议漂移风险。

## 架构

```
worker × N (concurrency)
    │
    ├─ ramp limiter (golang.org/x/time/rate)  ← 限流匀速放行 worker
    │
    └─ Scenario.Run                            ← 一次完整玩家会话
        │
        ├─ auth :2208            game :7877
        │  ↓                     ↓
        │  SM_KEY                SM_SESSION_KEY
        │  CM_AUTH_LOGIN         CM_SESSION_CONFIRM
        │  SM_LOGIN_OK           SM_CHARACTER_LIST
        │  CM_PLAY               CM_LOGOUT
        │  SM_PLAY_OK
        │
        └─ PhaseObserver  → Prometheus histogram + counter（:9091/metrics）
```

## 用法

```bash
# 编译
cd D:/拾光ai/ACE_5.8/server/src
go build ./cmd/loadgen -o ../bin/loadgen.exe

# 默认压本地 dev gateway，500 并发，60s ramp，5min 总时长
./bin/loadgen.exe \
  -target=127.0.0.1:2208 \
  -game-port=7877 \
  -concurrency=500 \
  -ramp=60s \
  -duration=5m \
  -metrics-addr=127.0.0.1:9091

# 拉指标
curl http://127.0.0.1:9091/metrics | grep loadgen_
```

## Prometheus 指标

| 指标 | 类型 | 说明 |
|------|------|------|
| `loadgen_phase_latency_seconds{phase=...}` | Histogram | 每个 phase 的耗时分布。bucket 1ms..10s。 |
| `loadgen_phase_errors_total{phase=...}`     | Counter   | 每个 phase 的失败累计。 |
| `loadgen_active_sessions`                   | Gauge     | 当前正在跑 Run 的 worker 数。 |
| `loadgen_sessions_started_total`            | Counter   | 累计启动 session 数。 |
| `loadgen_sessions_success_total`            | Counter   | 完整跑完 auth+game+logout 的 session 数。 |
| `loadgen_sessions_failed_total`             | Counter   | Run 返回 error 的 session 数。 |

Phase label 取值见 `scenario.go::AllPhases`：`connect_auth` / `recv_sm_key` / `send_auth_login` / `recv_login_resp` / `send_play` / `recv_play_resp` / `connect_game` / `recv_session_key` / `send_session_confirm` / `recv_char_list` / `send_logout`。

## 实测 baseline

> **TODO（等真实 dev/prod 跑一轮后填数）**
>
> | 并发 | ramp | duration | p50 connect_auth | p99 send_auth_login | p99 recv_login_resp | session success rate |
> |-----|------|----------|------------------|---------------------|---------------------|----------------------|
> | 100 | 30s  | 5m       | TBD              | TBD                 | TBD                 | TBD                  |
> | 500 | 60s  | 5m       | TBD              | TBD                 | TBD                 | TBD                  |

参考 tinyclient HEAD README 中标定的单连接 RTT：auth phase 整体 ~110ms，enter world ~2s。

## 4 大 risk note（违反必产 bug 或测错）

1. **必须复用 randName**：1000 并发若用静态 account name，`ap_create_account` 主键冲突；本工具的 `randName("lg_", 12)` 与 `cmd/tinyclient` working-tree 版逐字一致，`alphabet=32 × suffix=12 ≈ 10^18` 唯一空间。

2. **histogram bucket 不调失真**：默认 buckets 来自 tinyclient 实测（auth 110ms / enter world 2s）。如果换更高 RTT 网络（跨机房压 prod），必须把 bucket 顶端从 10s 提高，否则 p99 会被 `+Inf` 吞掉，看到的 p99 是 buckets 上界而非真实值。

3. **devredis 单机扛不住 1000 并发**：dev/prod 起 loadgen 前必须确认 redis 已切真 `redis-server` 或 `dragonfly` 而非 `cmd/devredis`（in-process 单 goroutine，1000 并发 session.cache 写会瞬间排长队，把 RTT 噪声塞进 phase histogram，测的就不再是 gateway 而是 redis）。

4. **tinyclient working-tree 改动中（另一会话）**：本工具故意从 git HEAD 抽取 phase 流程作为基底（**不**直接 import `cmd/tinyclient`，因为 cmd 包不可 import；逻辑等价 fork）。tinyclient working-tree 改完合并后再回看是否需要同步 phase 序列扩展。

## 文件清单

- `main.go` — CLI flag + worker pool + signal/duration cancel + metrics server
- `scenario.go` — Scenario 对象（一次完整玩家会话）+ randName + RSA encryptCredentials
- `metrics.go` — Prometheus registry + per-phase histogram/counter + active gauge
- `ramp.go` — golang.org/x/time/rate 限流封装
- `scenario_test.go` — randName / encryptCredentials / metrics 路径 + mock-server smoke
- `ramp_test.go` — RampSchedule 数学 + limiter 线性 ramp 上界

## 测试

```bash
go test ./cmd/loadgen -v -count=1
```

12 个测试覆盖：
- ramp 线性化（500 worker × 2s ramp，半程 ±30% 容忍）
- limiter cancel 即时退出
- randName 1000 次零碰撞
- RSA scramble byte 边界（modulus 全 0xFF）
- 账号 >17 字节硬拒
- metrics histogram + error counter 路径
- Scenario.Run 对垃圾 server / 半合法 server 的稳态行为
- AllPhases preheat（首次 scrape 不缺线）
