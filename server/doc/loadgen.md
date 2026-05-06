# Load Generator

> AionCore 5.8 协议级压测工具。**不是任意 TCP load**——和 server 共享同一份 `internal/crypto` + `internal/aionproto`，零协议漂移。
>
> 完整工程文档（CLI / 指标 / risk / 文件清单）在 [`../src/cmd/loadgen/README.md`](../src/cmd/loadgen/README.md)。本文是**项目级索引**，给运维 / 部署同学速查。

## 一句话定位

跑一台 dev/prod gateway，模拟 N 路真实玩家会话（auth → 角色列表 → enter world → logout），按 phase 拆分 latency/error 直方图导给 Prometheus。

## 端到端拓扑

```
loadgen workers × N
   │
   ├─ ramp limiter (golang.org/x/time/rate)         ← 匀速放行
   │
   └─ Scenario.Run                                   ← 一次完整会话
       │
       ├─ auth phase   (BF-LE + RSA-NoPad + XOR seed=1234)
       └─ game phase   (BF-LE + 业务包)
       │
       └─ PhaseObserver → Prometheus :9091/metrics
```

## 快速使用

```bash
cd D:/拾光ai/ACE_5.8/server/src
go build ./cmd/loadgen -o ../bin/loadgen.exe

./bin/loadgen.exe \
  -target=127.0.0.1:2208 \
  -game-port=7877 \
  -concurrency=500 \
  -ramp=60s \
  -duration=5m \
  -metrics-addr=127.0.0.1:9091

curl http://127.0.0.1:9091/metrics | grep loadgen_
```

## 关键指标

| 名称 | 类型 | 标签 | 含义 |
|------|------|------|------|
| `loadgen_phase_latency_seconds` | Histogram | `phase` | 每 phase 的耗时，bucket 1ms..10s |
| `loadgen_phase_errors_total` | Counter | `phase` | 每 phase 失败累计 |
| `loadgen_active_sessions` | Gauge | — | 当前在跑 worker 数 |
| `loadgen_sessions_started_total` | Counter | — | 启动 session 累计 |
| `loadgen_sessions_success_total` | Counter | — | 完整成功累计 |
| `loadgen_sessions_failed_total` | Counter | — | 失败累计 |

phase 取值：`connect_auth` / `recv_sm_key` / `send_auth_login` / `recv_login_resp` / `send_play` / `recv_play_resp` / `connect_game` / `recv_session_key` / `send_session_confirm` / `recv_char_list` / `send_logout`。

## 4 大 risk note（必看）

1. **必须复用 `randName`** — 1000 并发用静态账号会撞 `ap_create_account` 主键
2. **histogram bucket 不调失真** — bucket 顶端 10s，跨机房压 prod 必须扩，否则 p99 被 `+Inf` 吞
3. **devredis 单 goroutine 扛不住 1000 并发** — 起 loadgen 前必须切真 redis-server / dragonfly
4. **tinyclient working-tree 改动期** — 本工具从 git HEAD 抽出 phase 逻辑做基底；handler 合流后需回看是否同步扩展

## 何时用 loadgen

- 上线前压测：dev gateway → 测稳态承载（QPS / p99 / error rate）
- 回归门槛：每个大 PR 跑一轮，对比 baseline 不退化
- 容量规划：测出"每 100 worker 多消耗 X CPU / Y MB"，反推所需机器规格
- 协议变更验证：扩 phase 序列、改 opcode 后跑一轮，确保握手仍闭环

## 何时**不要**用 loadgen

- 测玩家行为多样性 / AI bot 行为：用专门的行为驱动 bot，loadgen 只跑握手核
- 测客户端兼容：客户端协议栈差异（XOR 校验等）loadgen 走的是 server 同款代码，假阳性
- 调 NATS / PG 单点：直接拿 nats-bench / pgbench，不要绕协议层

## 测试

```bash
go test ./cmd/loadgen -v -count=1   # 12 PASS
```

详见 `cmd/loadgen/README.md` 的"测试"段。
