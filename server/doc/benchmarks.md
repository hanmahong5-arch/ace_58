# 性能基线 / AionCore 5.8 Microbenchmarks

> Round 11 / Task A2 — 重写。**中文为主，英文术语保留。**
>
> 文件结构：
> 1. [快速使用](#快速使用) — 怎么跑
> 2. [当前覆盖](#当前覆盖) — 三个 internal 包的 bench 列表 + 阈值
> 3. [对比工作流](#对比工作流) — benchstat
> 4. [历史基线](#历史基线-2026-04-22) — 2026-04-22 单次跑的实测数

CI 友好原则：crypto / luahost bench 纯 CPU，无外部依赖；database bench 走
`AION_TEST_PG_*` 环境变量 gate，不设置就 `b.Skip` 无静默失败。

---

## 快速使用

A1 已加 `make bench` target (Makefile)，两条等价命令任选：

```bash
# 通过 Makefile (推荐)
cd server
make bench

# 直接 go test (CI 用，可加更多 flag)
cd server/src
go test -run='^$' -bench=. -benchtime=1x -benchmem ./internal/crypto ./internal/luahost
```

Database bench 需要先 export PG 环境变量 (与 internal/database/migrate_test.go
共用同一套 testDSN tuple)：

```bash
export AION_TEST_PG_HOST=127.0.0.1
export AION_TEST_PG_PORT=5432           # 可选，默认 5432
export AION_TEST_PG_DB=aion_world_live
export AION_TEST_PG_USER=postgres
export AION_TEST_PG_PASS=...
cd server/src
go test -run='^$' -bench=. -benchtime=100x -benchmem ./internal/database
```

不 export 上面任何一个 → bench 整体 `b.Skip`，**不会让 CI 红灯**。

调试性能回归常用 flag:

- `-benchmem` 出 B/op、allocs/op (推荐常开)
- `-benchtime=2s` 拉长每个 bench (默认 1s)
- `-benchtime=100x` 固定迭代数 (CI 短跑专用)
- `-cpuprofile cpu.out -memprofile mem.out` 产 profile，配合 `go tool pprof`
- `-cpu=8,16` 多核扫，看 mutex 争用曲线

---

## 当前覆盖

### `internal/crypto` — Blowfish-LE / XOR / RSA

| Bench | 测什么 | 期望阈值 (Ryzen 7 5700X 单核) |
|-------|--------|------------------------------|
| `BenchmarkBlowfishLE_Encrypt8` | 单 8B block 加密 | < 100 ns/op，0 allocs/op |
| `BenchmarkBlowfishLE_Decrypt8` | 单 8B block 解密 | < 100 ns/op，0 allocs/op |
| `BenchmarkXORSeed_64` | 64B XOR (seed=1234) | < 500 ns/op，1 alloc/op (cipher 重建) |
| `BenchmarkRSA_Decrypt128` | 1024-bit NoPad 解密 | < 200 µs/op (登录峰值瓶颈) |

`BenchmarkRSA_Decrypt128` 是登录 path 的硬限制：单核 5000 op/s ≈ 5000 登录/秒
理论上限。如果出现回归 > 500 µs，立刻看 RSA 库版本 / 是否被 race detector 启用。

补充覆盖 (旧 `blowfish_le_bench_test.go` / `xor_bench_test.go` 提供的更大粒度
吞吐数，跑 `make bench` 会一并出来)：

| Bench | 测什么 | 阈值 |
|-------|--------|------|
| `BenchmarkBFEncryptBlock` | 单 block 老命名 | < 60 ns/op |
| `BenchmarkBFEncryptPayload1KB` | 1 KiB packet 加密 | > 150 MB/s |
| `BenchmarkBFEncryptPayload16KB` | 16 KiB packet | > 150 MB/s |
| `BenchmarkBFEncryptPayloadParallel` | 多核并行 (RunParallel) | > 1500 MB/s 聚合 |
| `BenchmarkXOREncode` / `BenchmarkXORDecode` | 1 KiB stateful XOR | > 800 MB/s |

### `internal/luahost` — VM 池 + Go→Lua 派发

| Bench | 测什么 | 阈值 |
|-------|--------|------|
| `BenchmarkVMPool_AcquireRelease` | mutex-guarded checkout | < 20 ns/op，0 allocs/op |
| `BenchmarkCallGlobal_Noop` | 零参 Go→Lua dispatch | < 200 ns/op |
| `BenchmarkCallGlobal_IntArgs` | 4 个 int 参 | < 500 ns/op，<= 4 allocs/op |
| `BenchmarkBridgeBuild` | 构造 Bridge 结构 | < 200 ns/op，1 alloc/op |

旧 `pool_bench_test.go` 的同义 bench 也仍跑：`BenchmarkVMAcquireRelease` /
`BenchmarkCallGlobal` / `BenchmarkCallGlobalWithArgs` (3 参版本)。命名不同
是历史原因，新 bench 用 underscore 命名约定方便 grep。

> **设计取舍**: VMPool 容量取 4 (`setupBenchVM` 默认值) — 足以暴露 mutex
> 争用，又不必为 1800 CCU 的实际容量买单。`BenchmarkBridgeBuild` 故意不调
> `Register()`：那是另一个独立命题 (cost-of-API-surface)，下一轮要测可以
> 单加一个 `BenchmarkBridgeRegister`。

### `internal/database` — PG 存储过程

| Bench | 测什么 | 阈值 (本机 PG，loopback) |
|-------|--------|--------------------------|
| `BenchmarkSP_GetCharIdByName` | mail 投递热路径 | < 1 ms/op |
| `BenchmarkSP_GetBindPoint` | 死亡复活热路径 | < 1 ms/op |
| `BenchmarkPool_Acquire` | pgxpool 自身开销 (baseline) | < 10 µs/op |

清理 band: `9099000..9099099`。bench 启动 + 退出各跑一次 DELETE，避免和
`sp_get_char_id_by_name_test.go` 的 `9000800..9000899` band / `sp_bind_point_test.go`
的 `9000700..9000799` band 撞车。

`BenchmarkSP_GetCharIdByName` 和 `BenchmarkPool_Acquire` 的差值 ≈ "纯 PG
round-trip + planner cache" 成本。如果差值膨胀 > 200 µs 说明 SP 内部走了
seq scan 或 lock 等待。

---

## 对比工作流

性能回归用 `benchstat` 看是否 statistically significant：

```bash
go install golang.org/x/perf/cmd/benchstat@latest

# baseline (改之前)
cd server/src
go test -run='^$' -bench=. -benchtime=2s -count=10 -benchmem \
    ./internal/crypto ./internal/luahost > /tmp/old.txt

# 改完后
go test -run='^$' -bench=. -benchtime=2s -count=10 -benchmem \
    ./internal/crypto ./internal/luahost > /tmp/new.txt

benchstat /tmp/old.txt /tmp/new.txt
```

`-count=10` 让 benchstat 算 p-value (它要求 >= 5)。看到 `~` 就是变化在
噪声以内，`+5%` 之类带百分比的就是 95% 置信区间内的真实变化。

不强制把 baseline 文件 commit 进 repo — 性能基线随硬件变化，没有"绝对"
基线，每个 PR 用作者本机的 before/after 对比即可。CI 跑 `make bench` 只
做"能跑通 + 没崩"的 smoke test。

---

## 历史基线 (2026-04-22)

> 这一节是历史快照，2026-04-22 单次 2s 跑的实测数 (Windows 10, AMD Ryzen
> 7 5700X, 16 threads, `go 1.25.0`)。**仅供参考，不是 SLA**。生产 box 用
> Linux + 不同 CPU，重新跑过再做容量决策。

### `internal/crypto` (post-fix Blowfish 零分配)

| Benchmark | ns/op | Throughput | B/op | allocs/op |
|-----------|------:|-----------:|-----:|----------:|
| BFEncryptBlock                    | 52.3  | —            |    0 | 0 |
| BFEncryptPayload1KB               | 5853  | 175.0 MB/s   |    0 | 0 |
| BFEncryptPayload16KB              | 93558 | 175.1 MB/s   |    0 | 0 |
| BFEncryptPayloadParallel (1 KiB)  | 488.9 | **2094.5 MB/s** | 0 | 0 |
| XOREncode (1 KiB)                 | 1036  | 988.4 MB/s   |    0 | 0 |
| XORDecode (1 KiB)                 | 992.9 | 1031.3 MB/s  |    0 | 0 |

历史回归说明 (2026-04-22): 把 `inner stdBlowfishBlock` interface 字段
换成具象 `*stdblowfish.Cipher` 后，escape analysis 把 `tmp` 留在栈上 →
BFEncryptBlock 从 8 B/op 1 alloc/op 降到 0/0；1 KiB 吞吐 +54%。

### `internal/luahost`

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| VMAcquireRelease          | 8.9   | 0  | 0 |
| CallGlobal (noop)         | 82.5  | 0  | 0 |
| CallGlobalWithArgs (3 num)| 152.5 | 24 | 3 |

### `internal/ecs`

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| EntityCreate | 230.7 | 73 | 0* |
| SetStat      | 21.3  | 0  | 0 |
| GetStat      | 13.1  | 0  | 0 |

*EntityCreate 73 B/op 来自偶发 map bucket grow，按多次摊销。

### `internal/aionproto`

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| PacketEncode (7 fields) | 28.2 | 64 | 1 |
| PacketDecode (7 fields) | 24.7 | 32 | 1 |

### 1800 CCU 容量结论 (Ryzen 7 5700X 单机参考)

- Blowfish 1 KiB × 2000 CCU × 10 KB/s ≈ 20 MB/s — 单核即可覆盖。
- 多核并行 ~2 GB/s 聚合 — 58× headroom。
- VMPool 9 ns acquire — uncontended；上 1800 CCU 实际负载要重测 mutex 争用。
- CallGlobal ~80 ns base + ~25 ns/arg + 1 alloc/arg — Lua hook 在紧密内
  循环用要警惕。
- ECS / 协议层都在 < 30 ns — 不是瓶颈。

**今天没有任何 hot path 被标为 1800 玩家 blocker。** Blowfish 分配问题
已修；其他都至少有一个数量级 headroom。
