# AionCore 5.8 — Microbenchmarks

First-pass benchmark coverage for the hot paths of the Go runtime. Numbers
below are from a single 2s run on the developer's Windows 10 box
(AMD Ryzen 7 5700X, 16 threads, `go 1.25.0`). They are **indicative, not
absolute** — production boxes and load conditions will differ. Re-run on
the target deployment host before drawing capacity-planning conclusions.

## How to run

```bash
cd server/src

# Fast sanity check (single iteration per bench).
go test -bench=. -benchtime=1x -run=^$ ./internal/crypto ./internal/luahost ./internal/ecs ./internal/aionproto

# Full pass with allocation stats.
go test -bench=. -benchtime=2s -benchmem -run=^$ \
    ./internal/crypto ./internal/luahost ./internal/ecs ./internal/aionproto
```

Add `-cpuprofile cpu.out -memprofile mem.out` when chasing regressions.

## First-run results (2026-04-22)

### `internal/crypto` — Blowfish-LE + XOR

| Benchmark | ns/op | Throughput | B/op | allocs/op |
|-----------|------:|-----------:|-----:|----------:|
| BFEncryptBlock            | 57.5  | —            |   8 | 1 |
| BFDecryptBlock            | 59.1  | —            |   8 | 1 |
| BFEncryptPayload1KB       | 9015  | 113.6 MB/s   | 1024 | 128 |
| BFEncryptPayload16KB      | 122587 | 133.7 MB/s  | 16384 | 2048 |
| XOREncode (1 KiB)         | 1036  | 988.4 MB/s   | 0 | 0 |
| XORDecode (1 KiB)         | 992.9 | 1031.3 MB/s  | 0 | 0 |

### `internal/crypto` — post-fix (2026-04-22, same hardware)

After replacing the `stdBlowfishBlock` interface field with the concrete
`*stdblowfish.Cipher` type, the stack-local `var tmp [8]byte` in
`EncryptBlock`/`DecryptBlock` no longer escapes. Devirtualisation also
enables the standard cipher's `Encrypt` call to be treated as non-leaking
by escape analysis.

| Benchmark | ns/op | Throughput | B/op | allocs/op |
|-----------|------:|-----------:|-----:|----------:|
| BFEncryptBlock                    | 52.3  | —            |    0 | **0** |
| BFEncryptPayload1KB               | 5853  | 175.0 MB/s   |    0 | **0** |
| BFEncryptPayload16KB              | 93558 | 175.1 MB/s   |    0 | **0** |
| BFEncryptPayloadParallel (1 KiB)  | 488.9 | **2094.5 MB/s** |    0 | **0** |

- Per-block latency: 57.5 → 52.3 ns/op (-9 %).
- 1 KiB payload: 113.6 → 175.0 MB/s (+54 %); 128 allocs → 0.
- 16 KiB payload: 133.7 → 175.1 MB/s (+31 %); 2048 allocs → 0.
- Parallel (16 goroutines, Ryzen 7 5700X, 8c/16t): 2.09 GB/s aggregate.
  At 1800 CCU × 20 pkt/s × 1 KiB ≈ 36 MiB/s sustained — **~58× headroom**
  on this hardware; dedicated Linux production boxes should exceed that.
- GC pressure from the cipher is now zero on the steady-state path.

### `internal/luahost` — VM pool and Go→Lua dispatch

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| VMAcquireRelease          | 8.9   | 0  | 0 |
| CallGlobal (noop)         | 82.5  | 0  | 0 |
| CallGlobalWithArgs (3 num)| 152.5 | 24 | 3 |

### `internal/ecs` — World API

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| EntityCreate | 230.7 | 73 | 0* |
| SetStat      | 21.3  | 0  | 0 |
| GetStat      | 13.1  | 0  | 0 |

*EntityCreate's 73 B/op is from occasional map-bucket growth amortised over
many iterations; `allocs/op` rounds to 0.

### `internal/aionproto` — Packet codec

| Benchmark | ns/op | B/op | allocs/op |
|-----------|------:|-----:|----------:|
| PacketEncode (7 fields) | 28.2 | 64 | 1 |
| PacketDecode (7 fields) | 24.7 | 32 | 1 |

## Observations

1. ~~**`BFEncryptBlock` allocates 8 B per call.**~~ **Fixed 2026-04-22**:
   the `inner stdBlowfishBlock` interface field was replaced with a
   concrete `*stdblowfish.Cipher`. Escape analysis now proves `tmp` does
   not leak, eliminating both the per-block allocation and the associated
   GC pressure (was ~36 MiB/s at 1800 CCU). Single-core throughput rose
   ~55 % as a bonus.

2. **Blowfish throughput (~110 MB/s) is the gateway ceiling.** With
   XOR delivering ~10x faster, it is not a bottleneck. At 2000 players
   sending 10 KB/s each = 20 MB/s aggregate encrypt — well within budget
   on a single core, but leaves little headroom for spikes and assumes
   the allocation issue above is fixed.

3. **VMPool acquire is excellent (~9 ns).** The pool is mutex-guarded but
   uncontended in the benchmark. Under 1800-CCU real load the lock
   contention should be re-measured with `-benchtime=2s -cpu=8,16`.

4. **CallGlobal base cost is ~80 ns**; arguments add ~25 ns each plus
   one small alloc per arg for boxing. Acceptable but worth knowing when
   a Lua hook fires in a tight inner loop.

5. **ECS reads/writes are sub-25 ns.** Not a concern.

6. **Packet encode/decode sub-30 ns** with one alloc each (the backing
   buffer). Fine.

## Concrete recommendations

- ~~File a follow-up to eliminate the `[8]byte` heap escape in the BF
  block functions.~~ **Done** (2026-04-22). See "post-fix" table above.
- **Add a parallel benchmark for `VMAcquireRelease` with `b.RunParallel`**
  to quantify mutex contention before the next load-test run.
- **Re-measure on the target Linux production host.** Windows syscall
  overhead (fsnotify, map hashing) differs enough that 10-20% swing is
  expected.
- **No hot path flagged as a 1800-player blocker today.** Blowfish
  allocation is the only item that scales poorly; everything else has
  at least one order of magnitude of headroom.
