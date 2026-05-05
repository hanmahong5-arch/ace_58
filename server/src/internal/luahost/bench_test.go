// Package luahost — Round 11 / Task A2 benchmark surface.
//
// 这些 benchmark 是 pool_bench_test.go 的命题对齐版本：
// 名字与签名严格遵守 "BenchmarkVMPool_AcquireRelease / BenchmarkCallGlobal_Noop
// / BenchmarkCallGlobal_IntArgs / BenchmarkBridgeBuild" 四件套，方便 CI 用
// 固定名字的阈值表 (doc/benchmarks.md) 直接 grep。
//
// 设计取舍:
//   - VMPool 容量 = 4 (足以暴露 mutex 争用，又不必为 1800 CCU 实际容量买单)。
//   - 共用一个最小 Lua 脚本 (bench_noop / bench_add_args)，让 hot loop 远
//     离 script-load 噪声。
//   - Bridge 用 nil DB / nil Sender / nil Jobs / nil ECS 构造，BenchmarkBridgeBuild
//     就是测 "栈上裸结构 + atomic 字段初始化" 的最小成本。任何随后被 Register
//     调用的字段都不在本 bench scope，避免 cross-package import.
//
// 跑法 (无外部依赖):
//
//	cd server/src
//	go test -run='^$' -bench=. -benchtime=1x -benchmem ./internal/luahost
package luahost

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

// a2BenchSender 是 PacketSender 的 no-op 实现。
// 命名以 a2Bench 前缀避免和 scripts_test.go 的 mockSender / pool_bench_test.go
// 的 benchMockSender 撞符号。
type a2BenchSender struct{}

func (a2BenchSender) SendToPlayer(_ uint64, _ uint16, _ []byte) error { return nil }

// a2BenchDB 是 DBBridge 的 no-op 实现，永远返回空集。
type a2BenchDB struct{}

func (a2BenchDB) CallSP(_ context.Context, _ string, _ []any) ([]map[string]any, error) {
	return nil, nil
}

// setupBenchVM 构造一个最小 VMPool (capacity=4)，仅加载本 bench 用到的
// 两个 Lua 函数。返回的 cleanup 必须 defer 调用以释放临时目录。
func setupBenchVM(b *testing.B, capacity int) (*VMPool, func()) {
	b.Helper()
	dir, err := os.MkdirTemp("", "luahost-a2bench-*")
	if err != nil {
		b.Fatalf("mkdtemp: %v", err)
	}
	// bench_noop: 零参零返回 — Go→Lua dispatch 的成本下界。
	// bench_add_args: 接 4 个 int 参 — 暴露 goToLua + Lua 整型转换开销。
	script := `
function bench_noop() end
function bench_add_args(a, b, c, d) return a + b + c + d end
`
	if err := os.WriteFile(filepath.Join(dir, "bench.lua"), []byte(script), 0644); err != nil {
		b.Fatalf("write bench.lua: %v", err)
	}
	bridge := &Bridge{DB: a2BenchDB{}, Sender: a2BenchSender{}}
	pool, err := NewVMPool(capacity, dir, bridge)
	if err != nil {
		os.RemoveAll(dir)
		b.Fatalf("NewVMPool: %v", err)
	}
	cleanup := func() {
		pool.Close()
		os.RemoveAll(dir)
	}
	return pool, cleanup
}

// BenchmarkVMPool_AcquireRelease 测 mutex-guarded checkout/checkin 的纯成本。
// 每个 packet 派发都过这一关 — 1800 CCU 下要求 < ~1µs/op。
func BenchmarkVMPool_AcquireRelease(b *testing.B) {
	pool, cleanup := setupBenchVM(b, 4)
	defer cleanup()
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		L := pool.Acquire()
		pool.Release(L)
	}
}

// BenchmarkCallGlobal_Noop 测零参 PCall 的端到端成本 (Acquire + GetGlobal +
// PCall + Release)。这是 Go→Lua 任何业务调用的成本地板。
func BenchmarkCallGlobal_Noop(b *testing.B) {
	pool, cleanup := setupBenchVM(b, 4)
	defer cleanup()
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := pool.CallGlobal("bench_noop"); err != nil {
			b.Fatalf("CallGlobal: %v", err)
		}
	}
}

// BenchmarkCallGlobal_IntArgs 加 4 个整型参，差值 = goToLua 转换 + Lua 栈
// push 的边际成本。游戏内 jobq worker (auction expire / mail deliver)
// 普遍传 1-4 个 int，所以 4 是 representative。
func BenchmarkCallGlobal_IntArgs(b *testing.B) {
	pool, cleanup := setupBenchVM(b, 4)
	defer cleanup()
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := pool.CallGlobal("bench_add_args", 1, 2, 3, 4); err != nil {
			b.Fatalf("CallGlobal: %v", err)
		}
	}
}

// BenchmarkBridgeBuild 测构造一个 Bridge 结构体的成本 (atomic 字段、指针
// 引用)。World Engine 启动时只调一次，但 hot-reload 路径每次重建 VM 都
// 会复用同一个 Bridge — 实际意义是验证 "Bridge 不带任何昂贵 init 副作用"。
//
// 故意不调 Register: Register 会创建 ~10 张 Lua 表，是另一个独立命题
// (cost-of-API-surface)，不在本 bench scope。
func BenchmarkBridgeBuild(b *testing.B) {
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// 用 a2BenchSender / a2BenchDB 喂 nil 安全的 fake，DB/Jobs 字段
		// 留 nil 模拟 "World Engine 还没接 PG / Redis" 的早期启动态。
		_ = &Bridge{
			DB:     a2BenchDB{},
			Sender: a2BenchSender{},
			ECS:    nil,
			Jobs:   nil,
			Logger: nil,
		}
	}
}
